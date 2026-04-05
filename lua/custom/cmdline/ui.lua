-- nvim-cmdline/ui.lua
-- Complete UI revamp:
--   * All-rounded borders (╭─╮│╯─╰│) everywhere
--   * Icon badge left strip — distinct bg, bold icon, │ separator
--   * Mode-specific accent: blue for :cmd, green for /search
--   * No winblend on the 1-line input (keeps text crisp)
--   * Completion popup: winblend=12, ▸ selector, dim kind labels
--   * Counter rendered as  [3/20]  right-aligned in search accent
--   * Hint virt_lines below input (keys cheat-sheet)
--   * Execute runs in prev_win context (fixes %s/// wrong buffer)

local M = {}

local _pkg = (...):match("^(.+)%.[^.]+$") or error("[nvim-cmdline] ui.lua must be loaded as a submodule")

local animation = require(_pkg .. ".animation")
local completion = require(_pkg .. ".completion")
local search = require(_pkg .. ".search")
local history = require(_pkg .. ".history")
local colors = require(_pkg .. ".colors")
local modes = require(_pkg .. ".modes")
local debounce = require(_pkg .. ".debounce")
local preview = require(_pkg .. ".preview")

-- ---------------------------------------------------------------------------
-- Namespaces
-- ---------------------------------------------------------------------------
local NS_PROMPT = vim.api.nvim_create_namespace("nvim_cmdline_prompt")
local NS_COUNTER = vim.api.nvim_create_namespace("nvim_cmdline_counter")
local NS_HINT = vim.api.nvim_create_namespace("nvim_cmdline_hint")
local NS_BADGE = vim.api.nvim_create_namespace("nvim_cmdline_badge")

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local state = {
  win = nil,
  buf = nil,
  mode = nil,
  augroup = nil,
  saved_input = "",
  in_write = false,
  last_write_text = nil,
  target_row = 0,
  current_subtype = nil,
  range_win = nil,
  cancel_complete = nil,
  prev_win = nil,
}

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
M.config = {
  width_ratio = 0.58,
  max_width = 92,
  min_width = 52,
  animation = { enabled = true, steps = 4, duration_ms = 72 },
  border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  -- Set to true if your terminal font is a Nerd Font (enables icon glyphs).
  -- Set to false for ASCII-only prompts.
  -- When nil, auto-detects via vim.g.have_nerd_font.
  nerd_font = nil,
  completion = { debounce_ms = 40, auto_open = true, min_length = 1 },
  syntax = { enable = true },
  range_preview = { enable = true, context = 2, max_lines = 8 },
  live_preview = { enable = true },
  keymaps = {
    confirm = "<CR>",
    dismiss = { "<Esc>", "<C-c>" },
    complete = "<Tab>",
    complete_prev = "<S-Tab>",
    complete_show = "<C-d>",
    hist_older = { "<Up>", "<C-p>" },
    hist_newer = { "<Down>", "<C-n>" },
    word_del = "<C-w>",
    line_del = "<C-u>",
    go_home = { "<C-a>", "<Home>" },
    go_end = { "<C-e>", "<End>" },
  },
}

-- ---------------------------------------------------------------------------
-- Mode metadata
-- ---------------------------------------------------------------------------
-- PROMPT_LEN = 7 ASCII spaces in the buffer.
-- The badge virt_text (overlay) occupies exactly those 7 visual cells:
--   nerd font:  "  " (2) + icon (2) + " " (1) + "│" (1) + " " (1) = 7 cells
--   ascii:      " " (1) + ascii (1) + "  " (2) + "│" (1) + " " (1) = skipped to 7
-- Keeping the byte count simple: all non-icon chars are ASCII (1 byte = 1 cell).
local PROMPT_LEN = 7

---@class ModeInfo
---@field icon        string  nerd-font glyph (2 display cells)
---@field icon_ascii  string  ASCII fallback label (fits inside 7-cell prompt)
---@field title_nf    string  title text (nerd font version)
---@field title       string  title text (plain / fallback)
---@field badge_hl    string
---@field sep_hl      string
---@field border_hl   string
---@field title_hl    string
---@field hint        string

local MODE_INFO = {
  cmd = {
    icon = "  ",
    icon_ascii = " :  ",
    title_nf = "  Command",
    title = " Command",
    badge_hl = "NvimCmdlineBadge",
    sep_hl = "NvimCmdlineSep",
    border_hl = "NvimCmdlineBorder",
    title_hl = "NvimCmdlineFloatTitle",
    badge = "CMD",
    hint = {
      { "Tab", "complete" },
      { "Up/Down", "history" },
      { "Enter", "run" },
      { "Esc", "close" },
    },
  },
  search_fwd = {
    icon = "  ",
    icon_ascii = " /  ",
    title_nf = "  Search ↓",
    title = " Search ↓",
    badge_hl = "NvimCmdlineBadgeSearch",
    sep_hl = "NvimCmdlineSep",
    border_hl = "NvimCmdlineSearchBorder",
    title_hl = "NvimCmdlineSearchTitle",
    badge = "FIND",
    hint = {
      { "Up/Down", "history" },
      { "Enter", "next" },
      { "Esc", "close" },
    },
  },
  search_bwd = {
    icon = "  ",
    icon_ascii = " ?  ",
    title_nf = "  Search ↑",
    title = " Search ↑",
    badge_hl = "NvimCmdlineBadgeSearch",
    sep_hl = "NvimCmdlineSep",
    border_hl = "NvimCmdlineSearchBorder",
    title_hl = "NvimCmdlineSearchTitle",
    badge = "BACK",
    hint = {
      { "Up/Down", "history" },
      { "Enter", "prev" },
      { "Esc", "close" },
    },
  },
}

---Return true when nerd-font icons should be used.
---Priority: M.config.nerd_font (explicit) → vim.g.have_nerd_font → false.
local function use_nerd_font()
  if M.config.nerd_font ~= nil then
    return M.config.nerd_font == true
  end
  return vim.g.have_nerd_font == true or vim.g.have_nerd_font == 1
end

local get_title

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function get_width()
  local w = math.floor(vim.o.columns * M.config.width_ratio)
  return math.max(M.config.min_width, math.min(M.config.max_width, w))
end

local function get_col(w)
  return math.floor((vim.o.columns - w) / 2)
end

local function get_target_row()
  return math.max(0, vim.o.lines - vim.o.cmdheight - 3)
end

local function truncate_label(text, max_len)
  if type(text) ~= "string" then
    return ""
  end
  if #text <= max_len then
    return text
  end
  if max_len <= 1 then
    return text:sub(1, max_len)
  end
  return text:sub(1, max_len - 1) .. "…"
end

local function get_prev_buf()
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    local ok, buf = pcall(vim.api.nvim_win_get_buf, state.prev_win)
    if ok and type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      return buf
    end
  end
  return nil
end

local function get_prev_buf_meta()
  local buf = get_prev_buf()
  if not buf then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local basename = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
  local ft = vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "text"
  local modified = vim.bo[buf].modified
  local readonly = vim.bo[buf].readonly
  local line_count = vim.api.nvim_buf_line_count(buf)

  return {
    name = basename,
    ft = ft,
    modified = modified,
    readonly = readonly,
    line_count = line_count,
  }
end

local function get_variant_key(mode, subtype)
  if mode == "search_fwd" or mode == "search_bwd" then
    return "Search"
  end

  local title = subtype and subtype.title or ""
  if title:find("Lua", 1, true) or title:find("Expression", 1, true) then
    return "Lua"
  end
  if title:find("Shell", 1, true) or title:find("Terminal", 1, true) then
    return "Shell"
  end
  if title:find("Help", 1, true) then
    return "Help"
  end
  if title:find("Options", 1, true) then
    return "Opts"
  end
  if title:find("Substitute", 1, true) then
    return "Subst"
  end
  if title:find("Filter", 1, true) then
    return "Filter"
  end
  if title:find("File", 1, true) then
    return "File"
  end
  return "Cmd"
end

local function get_badge_hls(mode, subtype)
  local key = get_variant_key(mode, subtype)
  return "NvimCmdlineBadgeCol" .. key, "NvimCmdlineBadgeLabel" .. key
end

local function get_title_hls(mode, subtype)
  local key = get_variant_key(mode, subtype)
  return "NvimCmdlineTitleIcon" .. key, "NvimCmdlineTitleText" .. key
end

local function get_hint_key_hl(mode, subtype)
  local key = get_variant_key(mode, subtype)
  return "NvimCmdlineHintKey" .. key
end

local function get_title_chunks(mode, info, subtype)
  local icon_hl, text_hl = get_title_hls(mode, subtype)
  local title = vim.trim(get_title(info, subtype))
  local chunks = {
    { " " .. (info.badge or "CMD") .. " ", icon_hl },
    { " " .. title .. " ", text_hl },
  }

  if mode == "cmd" then
    chunks[#chunks + 1] = { " Live ", "NvimCmdlineBufInfoChip" }
  else
    chunks[#chunks + 1] = { " Matches ", "NvimCmdlineCounterChip" }
  end

  return chunks
end

local function get_footer_chunks(mode, subtype)
  local meta = get_prev_buf_meta()
  if not meta then
    return nil
  end

  local file_hl = mode == "cmd" and "NvimCmdlineBufInfoFile" or "NvimCmdlineBufInfoFileSearch"
  local chunks = {
    { " " .. truncate_label(meta.name, 28) .. " ", file_hl },
    { " ", "NvimCmdlineBufInfoSep" },
    { " " .. meta.ft .. " ", "NvimCmdlineBufInfoFt" },
    { " ", "NvimCmdlineBufInfoSep" },
    { (" %d lines "):format(meta.line_count), "NvimCmdlineBufInfoMeta" },
  }

  if meta.modified then
    chunks[#chunks + 1] = { " ", "NvimCmdlineBufInfoSep" }
    chunks[#chunks + 1] = { " +modified ", "NvimCmdlineBufInfoMod" }
  end
  if meta.readonly then
    chunks[#chunks + 1] = { " ", "NvimCmdlineBufInfoSep" }
    chunks[#chunks + 1] = { " read-only ", "NvimCmdlineBufInfoRO" }
  end

  return chunks
end

-- ---------------------------------------------------------------------------
-- Buffer I/O
-- Buffer stays permanently modifiable to avoid E21 errors.
-- ---------------------------------------------------------------------------

local function read_input(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end
  return (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""):sub(PROMPT_LEN + 1)
end

local function write_input(buf, win, text)
  if state.in_write then
    return
  end
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if type(text) ~= "string" then
    text = ""
  end
  state.in_write = true
  state.last_write_text = text
  local full = string.rep(" ", PROMPT_LEN) .. text
  pcall(vim.api.nvim_buf_set_lines, buf, 0, 1, false, { full })
  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_set_cursor, win, { 1, #full })
  end
  state.in_write = false
end

-- ---------------------------------------------------------------------------
-- Decorations
-- ---------------------------------------------------------------------------

---Render the icon badge as a virt_text overlay on the prompt area.
---Automatically uses nerd-font glyphs or ASCII depending on config.
local function render_badge(buf, info, subtype)
  vim.api.nvim_buf_clear_namespace(buf, NS_BADGE, 0, -1)

  local col_hl, _ = get_badge_hls(state.mode, subtype)
  local nf = use_nerd_font()
  local icon = (subtype and type(subtype.icon) == "string" and subtype.icon ~= "") and subtype.icon or info.icon
  local ascii_icon = (info.icon_ascii or " :  "):gsub("%s+", "")
  local badge_text = nf and ("  " .. icon .. " ") or (" " .. truncate_label(ascii_icon, 4) .. " ")
  pcall(vim.api.nvim_buf_set_extmark, buf, NS_BADGE, 0, 0, {
    virt_text = {
      { badge_text, info.badge_hl },
      { "│ ", info.sep_hl },
    },
    virt_text_pos = "overlay",
    priority = 60,
  })

  pcall(vim.api.nvim_buf_set_extmark, buf, NS_BADGE, 0, 0, {
    end_col = PROMPT_LEN,
    hl_group = col_hl,
    priority = 40,
  })
end

---Return the correct window title for the current state.
get_title = function(info, subtype)
  local nf = use_nerd_font()
  if subtype and type(subtype.title) == "string" and subtype.title ~= "" then
    return subtype.title
  end
  return nf and info.title_nf or info.title
end

---Keep prompt background consistent (behind the badge overlay).
local function render_prompt_hl(buf)
  vim.api.nvim_buf_clear_namespace(buf, NS_PROMPT, 0, -1)
  pcall(vim.api.nvim_buf_set_extmark, buf, NS_PROMPT, 0, 0, {
    end_col = PROMPT_LEN,
    hl_group = "NvimCmdlinePrompt",
    priority = 50,
  })
end

---Right-aligned search counter as eol virt_text.
local function render_counter(buf, count)
  vim.api.nvim_buf_clear_namespace(buf, NS_COUNTER, 0, -1)
  local label, hl = search.counter_label(count)
  pcall(vim.api.nvim_buf_set_extmark, buf, NS_COUNTER, 0, 0, {
    virt_text = { { label, hl } },
    virt_text_pos = "eol",
    priority = 100,
  })
end

---Hint line below the input via virt_lines (Nvim 0.10+ only).
local function render_hint(buf, info, subtype)
  vim.api.nvim_buf_clear_namespace(buf, NS_HINT, 0, -1)
  local hint = info.hint
  if type(hint) ~= "table" then
    pcall(vim.api.nvim_buf_set_extmark, buf, NS_HINT, 0, 0, {
      virt_lines = { { { tostring(hint or ""), "NvimCmdlineHint" } } },
      virt_lines_above = false,
      priority = 5,
    })
    return
  end

  local key_hl = get_hint_key_hl(state.mode, subtype)
  local chunks = { { "  ", "NvimCmdlineHintPad" } }
  for i, pair in ipairs(hint) do
    chunks[#chunks + 1] = { pair[1], key_hl }
    chunks[#chunks + 1] = { " " .. pair[2], "NvimCmdlineHintDesc" }
    if i < #hint then
      chunks[#chunks + 1] = { "  •  ", "NvimCmdlineHintSep" }
    end
  end
  chunks[#chunks + 1] = { "  ", "NvimCmdlineHintPad" }

  pcall(vim.api.nvim_buf_set_extmark, buf, NS_HINT, 0, 0, {
    virt_lines = { chunks },
    virt_lines_above = false,
    priority = 5,
  })
end

---Update the window border title (called when subtype changes).
local function render_title(win, info, subtype)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  pcall(vim.api.nvim_win_set_config, win, {
    title = get_title_chunks(state.mode, info, subtype),
    title_pos = "left",
    footer = get_footer_chunks(state.mode, subtype),
    footer_pos = "left",
  })
end

-- ---------------------------------------------------------------------------
-- Syntax
-- ---------------------------------------------------------------------------

local function apply_syntax(buf, subtype)
  if not M.config.syntax.enable then
    return
  end
  local lang = (subtype and type(subtype.lang) == "string") and subtype.lang or "vim"
  modes.apply_syntax(buf, lang)
  render_prompt_hl(buf)
end

-- ---------------------------------------------------------------------------
-- Range preview float
-- ---------------------------------------------------------------------------

local function close_range_preview()
  if state.range_win and vim.api.nvim_win_is_valid(state.range_win) then
    pcall(vim.api.nvim_win_close, state.range_win, true)
  end
  state.range_win = nil
end

local function parse_range_simple(range_str)
  if type(range_str) ~= "string" or range_str == "" then
    return nil
  end
  local lo_s = range_str:match("^([^,]+)")
  local hi_s = range_str:match(",(.+)$") or lo_s
  local function el(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(s)
    if n then
      return n
    end
    local ok, v = pcall(vim.fn.line, s)
    return (ok and type(v) == "number" and v > 0) and v or nil
  end
  local lo, hi = el(lo_s), el(hi_s)
  if not lo or not hi then
    return nil
  end
  return math.min(lo, hi), math.max(lo, hi)
end

local function show_range_preview(input, parent_win)
  close_range_preview()
  if not M.config.range_preview.enable then
    return
  end
  if type(input) ~= "string" then
    return
  end

  local range_str = input:match("^([%%%.%$%d,'<>%+%-]+)%s*$") or input:match("^([%%%.%$%d,'<>%+%-]+)%s+")
  if not range_str then
    return
  end

  local lo, hi
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    pcall(vim.api.nvim_win_call, state.prev_win, function()
      lo, hi = parse_range_simple(range_str)
    end)
  else
    lo, hi = parse_range_simple(range_str)
  end
  if not lo then
    return
  end

  local src_buf = state.prev_win
      and vim.api.nvim_win_is_valid(state.prev_win)
      and vim.api.nvim_win_get_buf(state.prev_win)
    or nil
  if not src_buf or not vim.api.nvim_buf_is_valid(src_buf) then
    return
  end

  local ctx = M.config.range_preview.context
  local max_ln = M.config.range_preview.max_lines
  local total = vim.api.nvim_buf_line_count(src_buf)
  local first = math.max(1, lo - ctx)
  local last = math.min(total, hi + ctx)
  local lines = vim.api.nvim_buf_get_lines(src_buf, first - 1, last, false)
  if #lines == 0 then
    return
  end
  if #lines > max_ln then
    lines = vim.list_slice(lines, 1, max_ln)
    lines[#lines + 1] = ("  … (%d more lines)"):format(last - first + 1 - max_ln)
  end

  local ok_c, pc = pcall(vim.api.nvim_win_get_config, parent_win)
  if not ok_c then
    return
  end

  local width = type(pc.width) == "number" and pc.width or 60
  local height = math.min(#lines, max_ln + 1)
  local row = math.max(0, (type(pc.row) == "number" and pc.row or 0) - height - 2)

  local pbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = pbuf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = pbuf })
  vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = pbuf })

  local pwin = vim.api.nvim_open_win(pbuf, false, {
    relative = "editor",
    row = row,
    col = type(pc.col) == "number" and pc.col or 0,
    width = width,
    height = height,
    style = "minimal",
    border = M.config.border_cmd or M.config.border,
    title = (" Lines %d – %d "):format(lo, hi),
    title_pos = "left",
    zindex = 190,
    focusable = false,
  })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NvimCmdlineOutput,FloatBorder:NvimCmdlineOutputBorder," .. "FloatTitle:NvimCmdlineFloatTitle",
    { win = pwin }
  )
  pcall(vim.api.nvim_set_option_value, "winblend", 10, { win = pwin })

  local ns = vim.api.nvim_create_namespace("nvim_cmdline_range_hl")
  for i = 1, #lines do
    local abs = first + i - 1
    if abs >= lo and abs <= hi then
      pcall(vim.api.nvim_buf_set_extmark, pbuf, ns, i - 1, 0, {
        line_hl_group = "NvimCmdlineMenuSel",
        priority = 10,
      })
    end
  end
  state.range_win = pwin
end

-- ---------------------------------------------------------------------------
-- Output float
-- ---------------------------------------------------------------------------

local function show_output(lines, is_error)
  if not lines or #lines == 0 then
    return
  end
  while #lines > 0 and (lines[#lines] or ""):match("^%s*$") do
    table.remove(lines)
  end
  if #lines == 0 then
    return
  end

  local width = get_width()
  local col = get_col(width)
  local height = math.min(#lines, 10)
  local row = math.max(0, get_target_row() - height - 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = M.config.border_cmd or M.config.border,
    title = is_error and " Error " or " Output ",
    title_pos = "left",
    zindex = 150,
    focusable = false,
  })
  if not ok then
    return
  end

  local hl = is_error and "NvimCmdlineError" or "NvimCmdlineOutput"
  vim.api.nvim_set_option_value(
    "winhighlight",
    ("Normal:%s,FloatBorder:NvimCmdlineOutputBorder,FloatTitle:NvimCmdlineFloatTitle"):format(hl),
    { win = win }
  )
  pcall(vim.api.nvim_set_option_value, "winblend", 10, { win = win })

  local uv = vim.uv or vim.loop
  local t = uv.new_timer()
  local dismissed = false
  local function dismiss()
    if dismissed then
      return
    end
    dismissed = true
    if not t:is_closing() then
      t:stop()
      t:close()
    end
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  t:start(5000, 0, vim.schedule_wrap(dismiss))
  -- Defer the CursorMoved autocmd by ~300 ms so that window-switch events
  -- fired by the slide-out animation (which runs ~75–100 ms) do not
  -- accidentally dismiss the output float before the user sees it.
  -- NOTE: BufWinLeave intentionally excluded for the same reason.
  vim.defer_fn(function()
    if dismissed then
      return
    end
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      once = true,
      callback = vim.schedule_wrap(dismiss),
    })
  end, 350)
end

-- ---------------------------------------------------------------------------
-- Blink.cmp suppression
-- ---------------------------------------------------------------------------

-- Cache the blink.cmp module so pcall(require) isn't called on every open/close.
local _blink_cache = nil
local _blink_checked = false

local blink_was_enabled = nil
local function blink_set_enabled(enable)
  if not _blink_checked then
    local ok, mod = pcall(require, "blink.cmp")
    _blink_cache = (ok and type(mod) == "table") and mod or false
    _blink_checked = true
  end
  local blink = _blink_cache
  if not blink then
    return
  end

  if enable then
    if blink_was_enabled ~= nil then
      if type(blink.set_enabled) == "function" then
        pcall(blink.set_enabled, true)
      else
        vim.g.blink_cmp_enabled = nil
      end
      blink_was_enabled = nil
    end
  else
    blink_was_enabled = true
    if type(blink.set_enabled) == "function" then
      pcall(blink.set_enabled, false)
    else
      vim.g.blink_cmp_enabled = false
    end
  end
end

-- ---------------------------------------------------------------------------
-- Close
-- ---------------------------------------------------------------------------

function M.close()
  blink_set_enabled(true)
  if state.cancel_complete then
    state.cancel_complete()
    state.cancel_complete = nil
  end
  completion.close()
  close_range_preview()
  if M.config.live_preview and M.config.live_preview.enable then
    preview.clear(state.prev_win)
  end
  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end

  local win = state.win
  state.win = nil
  state.buf = nil
  state.mode = nil
  state.current_subtype = nil
  state.last_write_text = nil
  state.target_row = 0
  state.prev_win = nil

  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  if M.config.animation.enabled then
    animation.slide_out(win, {
      steps = M.config.animation.steps,
      duration_ms = math.floor(M.config.animation.duration_ms * 0.7),
    }, function()
      vim.schedule(function()
        if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
          vim.cmd("stopinsert")
        end
      end)
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end)
  else
    if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
      vim.cmd("stopinsert")
    end
    pcall(vim.api.nvim_win_close, win, true)
  end
end

-- ---------------------------------------------------------------------------
-- Execute  (runs in prev_win context so %s/// hits the right buffer)
-- ---------------------------------------------------------------------------

local function execute(buf, mode)
  local input = read_input(buf)
  local prev_win = state.prev_win
  M.close()
  if input == "" then
    return
  end

  local function restore_and_run(fn)
    vim.schedule(function()
      if
        type(prev_win) == "number"
        and vim.api.nvim_win_is_valid(prev_win)
        and vim.api.nvim_get_current_win() ~= prev_win
      then
        pcall(vim.api.nvim_set_current_win, prev_win)
      end
      fn()
    end)
  end

  if mode == "cmd" then
    history.add(":", input)
    restore_and_run(function()
      -- NOTE: nvim_exec2() with output=true silently captures nothing when the
      -- cmdline-mode context has set redir_off=true (Neovim issue #35321).
      -- vim.fn.execute() explicitly resets redir_off before running the command,
      -- so it reliably captures output from :echo, :messages, :lua print(), etc.
      local ok, result = pcall(vim.fn.execute, input)
      local out, is_error
      if ok then
        out = type(result) == "string" and result or ""
        out = out:gsub("\nPress ENTER.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        is_error = false
      else
        out = tostring(result):gsub("^Vim%([^)]*%):", ""):gsub("^Vim:", ""):gsub("^%s+", "")
        is_error = true
      end
      if out ~= "" then
        show_output(vim.split(out, "\n", { plain = true }), is_error)
      end
    end)
  elseif mode == "search_fwd" or mode == "search_bwd" then
    local dir = mode == "search_fwd" and "/" or "?"
    history.add(dir, input)
    restore_and_run(function()
      search.commit(input, dir)
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Keymap helpers
-- ---------------------------------------------------------------------------

local function km(buf, lhs, fn)
  local bo = { buffer = buf, noremap = true, silent = true, nowait = true }
  if type(lhs) == "string" then
    if lhs ~= false then
      vim.keymap.set({ "i", "n" }, lhs, fn, bo)
    end
  elseif type(lhs) == "table" then
    for _, l in ipairs(lhs) do
      if type(l) == "string" then
        vim.keymap.set({ "i", "n" }, l, fn, bo)
      end
    end
  end
end

local function km_i(buf, lhs, fn)
  local bo = { buffer = buf, noremap = true, silent = true, nowait = true }
  if type(lhs) == "string" then
    if lhs ~= false then
      vim.keymap.set("i", lhs, fn, bo)
    end
  elseif type(lhs) == "table" then
    for _, l in ipairs(lhs) do
      if type(l) == "string" then
        vim.keymap.set("i", l, fn, bo)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------

local function setup_keymaps(buf, win, mode, info)
  local kc = M.config.keymaps

  km(buf, kc.confirm, function()
    execute(buf, mode)
  end)

  local function dismiss()
    if mode == "search_fwd" or mode == "search_bwd" then
      search.cancel()
    end
    M.close()
  end
  km(buf, kc.dismiss, dismiss)

  -- Completion (cmd mode)
  if mode == "cmd" then
    local function do_complete(forward)
      if state.cancel_complete then
        state.cancel_complete()
      end
      completion.lock()
      local input = read_input(buf)

      if completion.is_open() then
        local sel = forward and completion.select_next() or completion.select_prev()
        if sel then
          local base = input:match("^(.*[%s=])") or ""
          write_input(buf, win, base .. sel)
          render_prompt_hl(buf)
          render_badge(buf, info, state.current_subtype)
        end
      else
        completion.unlock()
        local items = completion.get_completions(input)
        if #items == 1 then
          write_input(buf, win, items[1])
          render_prompt_hl(buf)
          render_badge(buf, info, state.current_subtype)
          completion.unlock()
        elseif #items > 1 then
          local query = input:match("[^%s=]+$") or input
          local prefix = input:match("^(.*[%s=])") or ""
          completion.open(win, items, query, prefix, state.target_row, PROMPT_LEN, mode)
          completion.lock()
          local sel = forward and completion.select_next() or completion.select_prev()
          if sel then
            local base = input:match("^(.*[%s=])") or ""
            write_input(buf, win, base .. sel)
            render_prompt_hl(buf)
            render_badge(buf, info, state.current_subtype)
          end
        else
          completion.unlock()
        end
      end
    end

    km_i(buf, kc.complete, function()
      do_complete(true)
    end)
    km_i(buf, kc.complete_prev, function()
      do_complete(false)
    end)

    km_i(buf, kc.complete_show, function()
      if state.cancel_complete then
        state.cancel_complete()
      end
      completion.unlock()
      local input = read_input(buf)
      local items = completion.get_completions(input)
      if #items > 0 then
        completion.open(
          win,
          items,
          input:match("[^%s=]+$") or input,
          input:match("^(.*[%s=])") or "",
          state.target_row,
          PROMPT_LEN,
          mode
        )
      else
        completion.close()
      end
    end)
  end

  -- History
  local hist_type = mode == "cmd" and ":" or (mode == "search_fwd" and "/" or "?")

  local function update_counter_for(text)
    if mode == "search_fwd" or mode == "search_bwd" then
      local dir = mode == "search_fwd" and "/" or "?"
      local count = search.update(text, dir, state.prev_win)
      render_counter(buf, count)
    end
  end

  km_i(buf, kc.hist_older, function()
    completion.close()
    close_range_preview()
    local e = history.older(hist_type)
    if e then
      write_input(buf, win, e)
      render_prompt_hl(buf)
      render_badge(buf, info, state.current_subtype)
      update_counter_for(e)
    end
  end)

  km_i(buf, kc.hist_newer, function()
    completion.close()
    close_range_preview()
    local text = history.newer(hist_type) or state.saved_input
    write_input(buf, win, text)
    render_prompt_hl(buf)
    render_badge(buf, info, state.current_subtype)
    update_counter_for(text)
  end)

  km_i(buf, kc.word_del, function()
    write_input(buf, win, (read_input(buf):gsub("[^%s]+%s*$", "")))
    render_prompt_hl(buf)
  end)

  km_i(buf, kc.line_del, function()
    state.saved_input = ""
    write_input(buf, win, "")
    completion.close()
    close_range_preview()
    if mode == "search_fwd" or mode == "search_bwd" then
      search.cancel()
      render_counter(buf, { current = 0, total = 0, incomplete = false })
    end
    render_prompt_hl(buf)
  end)

  km_i(buf, kc.go_home, function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_cursor, win, { 1, PROMPT_LEN })
    end
  end)

  km_i(buf, kc.go_end, function()
    if vim.api.nvim_win_is_valid(win) then
      local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      pcall(vim.api.nvim_win_set_cursor, win, { 1, #line })
    end
  end)

  km_i(buf, "<Left>", function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(win)
    if pos[2] <= PROMPT_LEN then
      return
    end
    pcall(vim.api.nvim_win_set_cursor, win, { 1, pos[2] - 1 })
  end)

  km_i(buf, { "<BS>", "<C-h>" }, function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(win)
    if pos[2] <= PROMPT_LEN then
      return
    end
    vim.api.nvim_feedkeys(vim.keycode("<BS>"), "n", false)
  end)
end

-- ---------------------------------------------------------------------------
-- Autocmds
-- ---------------------------------------------------------------------------

local function setup_autocmds(buf, win, mode, info)
  local ag = vim.api.nvim_create_augroup("NvimCmdlineBuffer_" .. tostring(buf), { clear = true })
  state.augroup = ag

  local function do_update(input)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    -- Live buffer preview
    if M.config.live_preview and M.config.live_preview.enable and mode == "cmd" then
      preview.update(input, state.prev_win)
    end

    if mode == "cmd" then
      if input == "" or #input < M.config.completion.min_length then
        completion.close()
        return
      end
      if not M.config.completion.auto_open then
        return
      end
      local items = completion.get_completions(input)
      if #items > 0 then
        completion.open(
          win,
          items,
          input:match("[^%s=]+$") or input,
          input:match("^(.*[%s=])") or "",
          state.target_row,
          PROMPT_LEN,
          mode
        )
      else
        completion.close()
      end
    elseif mode == "search_fwd" or mode == "search_bwd" then
      local dir = mode == "search_fwd" and "/" or "?"
      local count = search.update(input, dir, state.prev_win)
      render_counter(buf, count)

      if M.config.completion.auto_open and #input >= M.config.completion.min_length then
        local words = completion.get_buffer_words(input)
        if #words > 0 then
          completion.open(win, words, input, "", state.target_row, PROMPT_LEN, mode)
        else
          completion.close()
        end
      end
    end
  end

  local debounced, cancel = debounce.new(do_update, M.config.completion.debounce_ms)
  state.cancel_complete = cancel

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = buf,
    group = ag,
    callback = function()
      if state.in_write then
        return
      end

      local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      local prefix = string.rep(" ", PROMPT_LEN)

      if line:sub(1, PROMPT_LEN) ~= prefix then
        write_input(buf, win, line:sub(PROMPT_LEN + 1))
        return
      end

      local input = line:sub(PROMPT_LEN + 1)

      -- Tab-cycle guard: if buffer changed to what Tab wrote, skip completion
      if state.last_write_text ~= nil then
        local was_tab = (input == state.last_write_text)
        state.last_write_text = nil
        if was_tab then
          render_prompt_hl(buf)
          render_badge(buf, info, state.current_subtype)
          return
        end
      end

      state.saved_input = input
      completion.unlock()

      -- Subtype detection and title update
      if mode == "cmd" then
        local subtype = modes.detect_cmd(input)
        if subtype ~= state.current_subtype then
          state.current_subtype = subtype
          render_badge(buf, info, subtype)
          render_hint(buf, info, subtype)
          render_title(win, info, subtype)
          apply_syntax(buf, subtype)
        end
        show_range_preview(input, win)
      end

      render_prompt_hl(buf)
      debounced(input)
    end,
  })

  -- Keep in insert mode
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = ag,
    pattern = "*:n",
    callback = function()
      if vim.api.nvim_get_current_buf() ~= buf then
        return
      end
      if state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_get_current_win() == state.win then
        vim.schedule(function()
          if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.cmd("startinsert!")
          end
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = ag,
    callback = function()
      vim.schedule(function()
        local cw = vim.api.nvim_get_current_win()
        if cw ~= state.win and cw ~= completion.get_win() then
          completion.close()
        end
      end)
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------

---Open the cmdline float.
---@param mode  string   "cmd" | "search_fwd" | "search_bwd"
---@param opts  table?   { default=string, prev_win=integer }
---@return integer
function M.open(mode, opts)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  end

  opts = opts or {}
  mode = mode or "cmd"

  local info = MODE_INFO[mode]
  if not info then
    vim.notify("[nvim-cmdline] unknown mode: " .. tostring(mode), vim.log.levels.ERROR)
    return -1
  end

  colors.setup_highlights()
  colors.setup_preview_highlights()

  -- Capture original window
  state.prev_win = (type(opts.prev_win) == "number" and vim.api.nvim_win_is_valid(opts.prev_win)) and opts.prev_win
    or vim.api.nvim_get_current_win()

  local width = get_width()
  local col = get_col(width)
  local target_row = get_target_row()
  local default = type(opts.default) == "string" and opts.default or ""

  state.target_row = target_row

  -- Subtype
  local subtype = mode == "cmd" and modes.detect_cmd(default) or modes.detect_search(mode)
  state.current_subtype = subtype

  -- Resolve border: prefer per-mode config strings, fall back to border table.
  local border = (mode == "cmd" and M.config.border_cmd)
    or ((mode == "search_fwd" or mode == "search_bwd") and M.config.border_search)
    or M.config.border

  -- ── Buffer ────────────────────────────────────────────────────────────────
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "nvim-cmdline", { buf = buf })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = buf })
  pcall(vim.api.nvim_buf_set_var, buf, "completion", false)
  pcall(vim.api.nvim_set_option_value, "completefunc", "", { buf = buf })
  pcall(vim.api.nvim_set_option_value, "omnifunc", "", { buf = buf })
  blink_set_enabled(false)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep(" ", PROMPT_LEN) .. default })

  -- ── Window ────────────────────────────────────────────────────────────────
  local start_row = M.config.animation.enabled and (target_row + M.config.animation.steps + 1) or target_row

  local title_text = get_title_chunks(mode, info, subtype)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = start_row,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = border,
    title = title_text,
    title_pos = "left",
    footer = get_footer_chunks(mode, subtype),
    footer_pos = "left",
    zindex = 200,
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    ("Normal:NvimCmdlineNormal,FloatBorder:%s,FloatTitle:%s"):format(info.border_hl, info.title_hl),
    { win = win }
  )
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("scrolloff", 0, { win = win })
  -- NO winblend on the input window — 1-line float with transparency looks bad

  -- ── State ─────────────────────────────────────────────────────────────────
  state.win = win
  state.buf = buf
  state.mode = mode
  state.saved_input = default
  state.in_write = false
  state.cancel_complete = nil

  -- ── Decorations ───────────────────────────────────────────────────────────
  render_prompt_hl(buf)
  render_badge(buf, info, subtype)
  render_hint(buf, info, subtype)

  if mode == "search_fwd" or mode == "search_bwd" then
    render_counter(buf, { current = 0, total = 0, incomplete = false })
    if default ~= "" then
      local dir = mode == "search_fwd" and "/" or "?"
      local count = search.update(default, dir, state.prev_win)
      render_counter(buf, count)
    end
  end

  apply_syntax(buf, subtype)

  -- ── Cursor + insert mode ──────────────────────────────────────────────────
  pcall(vim.api.nvim_win_set_cursor, win, { 1, PROMPT_LEN + #default })
  vim.cmd("startinsert!")

  -- ── Keymaps / autocmds ────────────────────────────────────────────────────
  local hist_char = mode == "cmd" and ":" or (mode == "search_fwd" and "/" or "?")
  history.reset(hist_char)
  setup_keymaps(buf, win, mode, info)
  setup_autocmds(buf, win, mode, info)

  -- ── Animation ─────────────────────────────────────────────────────────────
  if M.config.animation.enabled then
    animation.slide_in(win, target_row, {
      steps = M.config.animation.steps,
      duration_ms = M.config.animation.duration_ms,
    })
  end

  return win
end

return M
