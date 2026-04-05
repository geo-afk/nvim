-- nvim-cmdline/completion.lua
-- Floating completion popup.

local M = {}

local NS = vim.api.nvim_create_namespace("nvim_cmdline_completion")

local HAS_RIGHT_ALIGN = vim.fn.has("nvim-0.9") == 1

-- ---------------------------------------------------------------------------
-- Kind definitions
-- ---------------------------------------------------------------------------

---@class CompKind
---@field icon  string
---@field label string
---@field hl    string

---@type table<string, CompKind>
local KINDS = {
  command = { icon = "󰘬 ", label = "cmd", hl = "NvimCmdlineKindCmd" },
  file = { icon = "󰈙 ", label = "file", hl = "NvimCmdlineKindFile" },
  dir = { icon = "󰉋 ", label = "dir", hl = "NvimCmdlineKindDir" },
  option = { icon = "󰒓 ", label = "opt", hl = "NvimCmdlineKindOpt" },
  help = { icon = "󰋗 ", label = "help", hl = "NvimCmdlineKindHelp" },
  lua = { icon = "󰢱 ", label = "lua", hl = "NvimCmdlineKindLua" },
  shell = { icon = "󱁯 ", label = "sh", hl = "NvimCmdlineKindShell" },
  buffer = { icon = "󰈈 ", label = "buf", hl = "NvimCmdlineKindBuf" },
  color = { icon = "󰏘 ", label = "clr", hl = "NvimCmdlineKindColor" },
  event = { icon = "󰅐 ", label = "evt", hl = "NvimCmdlineKindEvt" },
  highlight = { icon = "󰨃 ", label = "hl", hl = "NvimCmdlineKindHl" },
  mapping = { icon = "󰌌 ", label = "map", hl = "NvimCmdlineKindMap" },
  substitute = { icon = "󰑕 ", label = "sub", hl = "NvimCmdlineKindSubst" },
  global = { icon = "󰌋 ", label = "gbl", hl = "NvimCmdlineKindGbl" },
  register = { icon = "󰅇 ", label = "reg", hl = "NvimCmdlineKindReg" },
  expression = { icon = "󰲋 ", label = "expr", hl = "NvimCmdlineKindExpr" },
  unknown = { icon = "󰂚 ", label = "", hl = "NvimCmdlineKindBadge" },
}

---@param item   string
---@param prefix string
---@return CompKind
local function guess_kind(item, prefix)
  if not item or item == "" then
    return KINDS.unknown
  end

  if item:sub(-1) == "/" or item:sub(-1) == "\\" then
    return KINDS.dir
  end
  if item:match("%.[a-zA-Z0-9_]+$") then
    return KINDS.file
  end

  if prefix:match("^%s*s%a*/") or prefix:match("^%s*substitute") then
    return KINDS.substitute
  end
  if prefix:match("^%s*[gv]/") then
    return KINDS.global
  end
  if prefix:match("^%s*reg") then
    return KINDS.register
  end
  if prefix:match("^%s*=%s*") then
    return KINDS.expression
  end
  if prefix:match("^%s*setl?%s") or prefix:match("^%s*setl?o") then
    return KINDS.option
  end
  if prefix:match("^%s*hi%S*") or prefix:match("^%s*highlight") then
    return KINDS.highlight
  end
  if prefix:match("^%s*[nvxioc]?n?o?r?e?map") then
    return KINDS.mapping
  end
  if prefix:match("^%s*colou?rscheme") then
    return KINDS.color
  end
  if prefix:match("^%s*au") or prefix:match("^%s*autocmd") then
    return KINDS.event
  end
  if prefix:match("^%s*he?l?p?%s") then
    return KINDS.help
  end
  if prefix:match("^%s*lua%s") or prefix:match("^%s*=%s*lua") or prefix:match("^%s*lua%s*=") then
    return KINDS.lua
  end
  if prefix:match("^%s*!") then
    return KINDS.shell
  end

  if item:match("^[%a_][%w_]*$") then
    local lo = item:lower()
    local CMD_SET = {
      set = 1,
      setlocal = 1,
      setglobal = 1,
      map = 1,
      nmap = 1,
      vmap = 1,
      imap = 1,
      command = 1,
      autocmd = 1,
      highlight = 1,
      syntax = 1,
      filetype = 1,
      colorscheme = 1,
      help = 1,
      echo = 1,
      execute = 1,
      call = 1,
      lua = 1,
      edit = 1,
      write = 1,
      read = 1,
      buffer = 1,
      bnext = 1,
      bprev = 1,
    }
    if CMD_SET[lo] then
      return KINDS.command
    end

    if
      lo:match("^no")
      or lo:match("^inv")
      or (#item <= 20 and (lo:match("^%l+$") or vim.fn.exists("&" .. item) == 1))
    then
      return KINDS.option
    end
    return KINDS.command
  end

  return KINDS.command
end

-- ---------------------------------------------------------------------------
-- Fuzzy scoring (case-insensitive)
-- ---------------------------------------------------------------------------
-- Returns an integer score >= 1 when `query` chars appear in order inside
-- `str`, or nil when there is no subsequence match.
-- Higher scores = better match. Bonuses for:
--   • Consecutive character runs
--   • Start-of-string matches
--   • Word-boundary matches (after space / _ / - / .)
--   • Exact prefix matches

local function fuzzy_score(str, query)
  if not query or query == "" then
    return 1
  end

  local sl = str:lower()
  local ql = query:lower()
  local qi = 1
  local score = 0
  local consecutive = 0
  local last_ci = -2

  for ci = 1, #sl do
    if qi > #ql then
      break
    end
    if sl:sub(ci, ci) == ql:sub(qi, qi) then
      -- Consecutive-run bonus (grows geometrically)
      if ci == last_ci + 1 then
        consecutive = consecutive + 1
        score = score + consecutive * 3
      else
        consecutive = 1
        score = score + 1
      end
      -- Start-of-string bonus
      if ci == 1 then
        score = score + 8
      end
      -- Word-boundary bonus
      if ci > 1 then
        local prev = sl:sub(ci - 1, ci - 1)
        if prev == " " or prev == "_" or prev == "-" or prev == "." then
          score = score + 4
        end
      end
      last_ci = ci
      qi = qi + 1
    end
  end

  if qi > #ql then
    -- Exact-prefix bonus
    if vim.startswith(sl, ql) then
      score = score + 50
    end
    -- Mild penalty for longer strings (prefer tighter matches)
    score = score - math.floor(#str / 8)
    return math.max(1, score)
  end

  return nil -- not all query chars matched
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local state = {
  win = nil,
  buf = nil,
  items = {},
  total = 0,
  window_start = 0,
  window_size = 0,
  selected = -1,
  global_index = -1,
  query = "",
  prefix = "",
  max_item_w = 0,
  popup_w = 0,
  locked = false,
  gutter = 6,
  gutter_hl = "NvimCmdlineCompGutter",
}

-- Per-render kind cache: avoids re-computing guess_kind() for each item on
-- every highlight redraw.  Keyed by item string; cleared on M.close().
local kind_cache = {} ---@type table<string, CompKind>

local MAX_VISIBLE = 10
local MIN_WIDTH = 30
local MAX_ITEM_LEN = 40
local MARK_DISPLAY = 2
local ICON_DISPLAY = 2

-- ---------------------------------------------------------------------------
-- Kind helper (with cache)
-- ---------------------------------------------------------------------------

local function get_kind(item)
  local k = kind_cache[item]
  if not k then
    k = guess_kind(item, state.prefix)
    kind_cache[item] = k
  end
  return k
end

-- ---------------------------------------------------------------------------
-- Line builder
-- ---------------------------------------------------------------------------

local function build_lines()
  local lines = {}
  local pad_w = state.max_item_w
  local gpad = string.rep(" ", state.gutter)

  for i = state.window_start, state.window_start + state.window_size - 1 do
    local item = state.items[i + 1]
    if not item then
      break
    end

    local s = item:sub(1, MAX_ITEM_LEN)
    local k = get_kind(s)
    local pad = pad_w - #s

    lines[#lines + 1] = gpad .. "  " .. k.icon .. s .. string.rep(" ", math.max(0, pad) + 2)
  end

  if state.total > state.window_size then
    local last_shown = state.window_start + state.window_size
    local indent = string.rep(" ", state.gutter + MARK_DISPLAY + ICON_DISPLAY)
    lines[#lines + 1] = indent
      .. ("%d – %d  of  %d"):format(state.window_start + 1, math.min(last_shown, state.total), state.total)
  end

  return lines
end

-- ---------------------------------------------------------------------------
-- Highlight application (per row)
-- ---------------------------------------------------------------------------

local function apply_hl(buf, row, item, query, kind, is_sel)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local llen = #line
  if llen == 0 then
    return
  end

  local G = state.gutter

  local base_hl = is_sel and "NvimCmdlineMenuSel" or "NvimCmdlineMenu"
  local match_hl = is_sel and "NvimCmdlineMenuSelMatch" or "NvimCmdlineMenuMatch"
  local icon_hl = is_sel and "NvimCmdlineMenuSelIcon" or "NvimCmdlineMenuIcon"
  local mark_hl = is_sel and "NvimCmdlineMenuSelMark" or "NvimCmdlineMenuMark"
  local badge_hl = is_sel and "NvimCmdlineKindBadgeSel" or (kind.hl or "NvimCmdlineKindBadge")
  local gutter_hl = state.gutter_hl

  -- 1. Base row highlight
  vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
    end_col = llen,
    hl_group = base_hl,
    priority = 10,
  })

  -- 2. Gutter strip background
  if G > 0 and G <= llen then
    vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
      end_col = G,
      hl_group = gutter_hl,
      priority = 20,
    })
  end

  -- 3. Gutter separator "│"
  if G < llen then
    vim.api.nvim_buf_set_extmark(buf, NS, row, G, {
      virt_text = { { "│", "NvimCmdlineSep" } },
      virt_text_pos = "overlay",
      priority = 65,
    })
  end

  -- 4. Selection marker "▸ " / "  "
  if G + 1 < llen then
    vim.api.nvim_buf_set_extmark(buf, NS, row, G, {
      virt_text = { { is_sel and "▸ " or "  ", mark_hl } },
      virt_text_pos = "overlay",
      priority = 60,
    })
  end

  -- 5. Icon highlight
  if kind.icon and kind.icon ~= "" then
    local icon_start = G + MARK_DISPLAY
    local icon_end = icon_start + #kind.icon
    if icon_end <= llen then
      vim.api.nvim_buf_set_extmark(buf, NS, row, icon_start, {
        end_col = icon_end,
        hl_group = icon_hl,
        priority = 55,
      })
    end
  end

  -- 6. Kind badge pill (right-aligned eol)
  if kind.label and kind.label ~= "" then
    vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
      virt_text = { { " " .. kind.label .. " ", badge_hl } },
      virt_text_pos = "eol",
      priority = 45,
    })
  end

  -- 7. Fuzzy-match character highlights (case-insensitive)
  --    Text starts at byte: G + MARK_DISPLAY + #kind.icon
  if query and query ~= "" then
    local text_start = G + MARK_DISPLAY + #kind.icon
    local ql = query:lower()
    local qi = 1
    for ci = 1, #item do
      if qi > #ql then
        break
      end
      if item:sub(ci, ci):lower() == ql:sub(qi, qi) then
        local col = text_start + ci - 1
        if col + 1 <= llen then
          vim.api.nvim_buf_set_extmark(buf, NS, row, col, {
            end_col = col + 1,
            hl_group = match_hl,
            priority = 30,
          })
        end
        qi = qi + 1
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Scrollbar
-- ---------------------------------------------------------------------------

local function render_scrollbar()
  if not HAS_RIGHT_ALIGN then
    return
  end
  if state.total <= state.window_size then
    return
  end

  local wsize = state.window_size
  local total = state.total
  local ws = state.window_start
  local thumb_size = math.max(1, math.floor(wsize * wsize / total))
  local max_start = wsize - thumb_size
  local thumb_top = math.min(max_start, math.floor(ws / (total - wsize) * max_start))

  for row = 0, wsize - 1 do
    local in_thumb = row >= thumb_top and row < thumb_top + thumb_size
    local ch = in_thumb and "█" or "░"
    local grp = in_thumb and "NvimCmdlineScrollThumb" or "NvimCmdlineScrollTrack"
    pcall(vim.api.nvim_buf_set_extmark, state.buf, NS, row, 0, {
      virt_text = { { ch, grp } },
      virt_text_pos = "right_align",
      priority = 200,
    })
  end
end

-- ---------------------------------------------------------------------------
-- Rebuild window content + highlights
-- ---------------------------------------------------------------------------

local function rebuild_window()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = build_lines()

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_set_config, state.win, { height = #lines })
  end

  M._redraw_highlights()
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Fetch Vim's built-in cmdline completions for `text`, with fuzzy fallback.
---
---The function works in two passes:
---  1. Ask Vim for exact completions.  These are fuzzy-sorted so that a
---     differently-cased query ("Buf" matching "buffer") ranks correctly.
---  2. If Vim returns nothing, strip the last word, get the broader
---     completion list for the prefix, and fuzzy-filter/sort against the word.
---     This handles cases like typing "bufn" and seeing "bnext".
---
---All matching is case-insensitive.
---@param text string
---@return string[]
function M.get_completions(text)
  if type(text) ~= "string" or text == "" then
    return {}
  end

  local word = text:match("[^%s=]+$") or text
  local base = text:match("^(.*[%s=])") or ""

  -- Pass 1: Vim's exact completions
  local ok, items = pcall(vim.fn.getcompletion, text, "cmdline")
  if not ok or type(items) ~= "table" then
    return {}
  end

  -- Fuzzy-sort the exact results so case differences rank properly
  if #items > 0 and word ~= "" then
    local scored = {}
    for _, item in ipairs(items) do
      scored[#scored + 1] = { item = item, score = fuzzy_score(item, word) or 0 }
    end
    table.sort(scored, function(a, b)
      return a.score > b.score
    end)
    local out = {}
    for _, v in ipairs(scored) do
      out[#out + 1] = v.item
    end
    return out
  end

  -- Pass 2: broaden + fuzzy filter when Vim found nothing
  if #items == 0 and #word >= 2 then
    local ok2, broad = pcall(vim.fn.getcompletion, base, "cmdline")
    if ok2 and type(broad) == "table" and #broad > 0 then
      local scored = {}
      for _, item in ipairs(broad) do
        local s = fuzzy_score(item, word)
        if s then
          scored[#scored + 1] = { item = item, score = s }
        end
      end
      table.sort(scored, function(a, b)
        return a.score > b.score
      end)
      for _, v in ipairs(scored) do
        items[#items + 1] = v.item
      end
    end
  end

  return items
end

---Collect words from loaded normal buffers that fuzzy-match `pattern`.
---@param pattern string
---@return string[]
function M.get_buffer_words(pattern)
  if type(pattern) ~= "string" then
    return {}
  end

  local words = {}
  local seen = {}
  local pl = pattern:lower()
  local MAX_WORDS = 200

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if #words >= MAX_WORDS then
      break
    end
    if not vim.api.nvim_buf_is_loaded(b) or not vim.api.nvim_buf_is_valid(b) then
      goto continue
    end
    local ok_bt, bt = pcall(vim.api.nvim_get_option_value, "buftype", { buf = b })
    if ok_bt and bt ~= "" then
      goto continue
    end

    local nlines = vim.api.nvim_buf_line_count(b)
    local ls = vim.api.nvim_buf_get_lines(b, 0, math.min(nlines, 1000), false)
    for _, ln in ipairs(ls) do
      if #words >= MAX_WORDS then
        break
      end
      for w in ln:gmatch("[%a_][%w_]+") do
        if not seen[w] and (pl == "" or fuzzy_score(w, pl)) then
          seen[w] = true
          words[#words + 1] = w
        end
      end
    end
    ::continue::
  end

  if pl ~= "" and #words > 1 then
    -- Sort: exact-prefix first, then by fuzzy score descending
    table.sort(words, function(a, b)
      local sa = fuzzy_score(a, pl) or 0
      local sb = fuzzy_score(b, pl) or 0
      if sa ~= sb then
        return sa > sb
      end
      return #a < #b
    end)
  end

  return words
end

function M.lock()
  state.locked = true
end
function M.unlock()
  state.locked = false
end

---Open the completion popup.
---@param parent_win  integer
---@param items       string[]
---@param query       string
---@param prefix      string
---@param cmdline_row integer?
---@param gutter      integer?
---@param mode        string?
function M.open(parent_win, items, query, prefix, cmdline_row, gutter, mode)
  if state.locked then
    return
  end
  M.close()
  if #items == 0 then
    return
  end

  prefix = type(prefix) == "string" and prefix or ""
  query = type(query) == "string" and query or ""
  gutter = type(gutter) == "number" and gutter or 6
  state.gutter = gutter
  state.gutter_hl = (mode == "search_fwd" or mode == "search_bwd") and "NvimCmdlineCompGutterSearch"
    or "NvimCmdlineCompGutter"

  -- Invalidate kind cache when prefix changes
  if state.prefix ~= prefix then
    kind_cache = {}
  end

  -- Max item display width
  local max_item = MIN_WIDTH - (MARK_DISPLAY + ICON_DISPLAY)
  for _, item in ipairs(items) do
    max_item = math.max(max_item, math.min(#item, MAX_ITEM_LEN))
  end

  -- Rows available above the cmdline
  local available_above
  if type(cmdline_row) == "number" and cmdline_row > 2 then
    available_above = cmdline_row - 1
  else
    local ok_cfg, pc = pcall(vim.api.nvim_win_get_config, parent_win)
    if ok_cfg and type(pc.row) == "number" and pc.row > 2 then
      available_above = pc.row - 1
    else
      available_above = math.max(4, math.floor(vim.o.lines / 2))
    end
  end

  local window_size = math.max(1, math.min(#items, MAX_VISIBLE, available_above - 3))
  local has_footer = #items > window_size
  local popup_h = window_size + (has_footer and 1 or 0)
  local content_w = gutter + MARK_DISPLAY + ICON_DISPLAY + max_item + 2

  local popup_col = 0
  local popup_w = content_w
  local ok_cfg, pc = pcall(vim.api.nvim_win_get_config, parent_win)
  if ok_cfg then
    popup_col = type(pc.col) == "number" and pc.col or 0
    popup_w = type(pc.width) == "number" and math.max(content_w, pc.width) or content_w
  end

  local ref_row = (type(cmdline_row) == "number" and cmdline_row > 0) and cmdline_row or available_above + 1
  local popup_row = math.max(0, ref_row - popup_h - 2)

  state.items = items
  state.total = #items
  state.window_start = 0
  state.window_size = window_size
  state.selected = -1
  state.global_index = -1
  state.query = query
  state.prefix = prefix
  state.max_item_w = max_item
  state.popup_w = popup_w

  local lines = build_lines()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = popup_row,
    col = popup_col,
    width = popup_w,
    height = #lines,
    style = "minimal",
    border = "rounded",
    zindex = 210,
    focusable = false,
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NvimCmdlineMenu,FloatBorder:NvimCmdlineMenuBorder,EndOfBuffer:NvimCmdlineMenu",
    { win = win }
  )
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  state.buf = buf
  state.win = win

  M._redraw_highlights()
end

---Select the next item (wraps around). Returns the selected item string.
function M.select_next()
  if not M.is_open() then
    return nil
  end

  local next_global = state.global_index < 0 and 0 or (state.global_index + 1) % state.total
  state.global_index = next_global

  if next_global >= state.window_start + state.window_size then
    state.window_start = next_global == 0 and 0 or next_global - state.window_size + 1
    rebuild_window()
  elseif next_global < state.window_start then
    state.window_start = 0
    rebuild_window()
  else
    state.selected = next_global - state.window_start
    M._redraw_highlights()
  end

  state.selected = next_global - state.window_start
  return state.items[next_global + 1]
end

---Select the previous item (wraps around). Returns the selected item string.
function M.select_prev()
  if not M.is_open() then
    return nil
  end

  local prev_global = state.global_index <= 0 and state.total - 1 or state.global_index - 1
  state.global_index = prev_global

  if prev_global < state.window_start then
    state.window_start = prev_global == state.total - 1 and math.max(0, state.total - state.window_size) or prev_global
    rebuild_window()
  elseif prev_global >= state.window_start + state.window_size then
    state.window_start = math.max(0, state.total - state.window_size)
    rebuild_window()
  else
    state.selected = prev_global - state.window_start
    M._redraw_highlights()
  end

  state.selected = prev_global - state.window_start
  return state.items[prev_global + 1]
end

---Redraw all highlights for the current window contents.
function M._redraw_highlights()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)

  for row = 0, state.window_size - 1 do
    local item = state.items[state.window_start + row + 1]
    if not item then
      break
    end
    local s = item:sub(1, MAX_ITEM_LEN)
    local k = get_kind(s)
    local is_sel = row == state.selected
    apply_hl(state.buf, row, s, state.query, k, is_sel)
  end

  -- Footer row
  if state.total > state.window_size then
    local fr = state.window_size
    local ft = vim.api.nvim_buf_get_lines(state.buf, fr, fr + 1, false)[1] or ""
    if #ft > 0 then
      vim.api.nvim_buf_set_extmark(state.buf, NS, fr, 0, {
        end_col = #ft,
        hl_group = "NvimCmdlineMenuFooter",
        priority = 10,
      })
    end
  end

  render_scrollbar()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.items = {}
  state.total = 0
  state.window_start = 0
  state.window_size = 0
  state.selected = -1
  state.global_index = -1
  state.query = ""
  state.prefix = ""
  state.max_item_w = 0
  state.popup_w = 0
  state.locked = false
  state.gutter = 6
  state.gutter_hl = "NvimCmdlineCompGutter"
  kind_cache = {}
end

function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.get_win()
  return state.win
end
function M.count()
  return state.total
end

return M
