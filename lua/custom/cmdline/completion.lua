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
---@field desc  string
---@field hl    string
---@field icon_w integer  display-cell width of icon (pre-computed)

---@type table<string, CompKind>
local KINDS = {
  command = { icon = "󰘬 ", label = "cmd", desc = "Vim Command", hl = "NvimCmdlineKindCmd" },
  file = { icon = "󰈙 ", label = "file", desc = "File Path", hl = "NvimCmdlineKindFile" },
  dir = { icon = "󰉋 ", label = "dir", desc = "Directory", hl = "NvimCmdlineKindDir" },
  option = { icon = "󰒓 ", label = "opt", desc = "Editor Option", hl = "NvimCmdlineKindOpt" },
  help = { icon = "󰋗 ", label = "help", desc = "Help Tag", hl = "NvimCmdlineKindHelp" },
  lua = { icon = "󰢱 ", label = "lua", desc = "Lua Code", hl = "NvimCmdlineKindLua" },
  shell = { icon = "󱁯 ", label = "sh", desc = "Shell Cmd", hl = "NvimCmdlineKindShell" },
  buffer = { icon = "󰈈 ", label = "buf", desc = "Buffer", hl = "NvimCmdlineKindBuf" },
  color = { icon = "󰏘 ", label = "clr", desc = "Colorscheme", hl = "NvimCmdlineKindColor" },
  event = { icon = "󰅐 ", label = "evt", desc = "Autocmd Event", hl = "NvimCmdlineKindEvt" },
  highlight = { icon = "󰨃 ", label = "hl", desc = "Highlight Group", hl = "NvimCmdlineKindHl" },
  mapping = { icon = "󰌌 ", label = "map", desc = "Key Mapping", hl = "NvimCmdlineKindMap" },
  substitute = { icon = "󰑕 ", label = "sub", desc = "Substitution", hl = "NvimCmdlineKindSubst" },
  global = { icon = "󰌋 ", label = "gbl", desc = "Global Command", hl = "NvimCmdlineKindGbl" },
  register = { icon = "󰅇 ", label = "reg", desc = "Vim Register", hl = "NvimCmdlineKindReg" },
  expression = { icon = "󰲋 ", label = "expr", desc = "Expression", hl = "NvimCmdlineKindExpr" },
  unknown = { icon = "󰂚 ", label = "", desc = "", hl = "NvimCmdlineKindBadge" },
}

-- Pre-compute display widths for icons once at load time so the hot path
-- never calls strdisplaywidth() on every keystroke.
for _, k in pairs(KINDS) do
  k.icon_w = vim.api.nvim_strwidth(k.icon)
end

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
      if ci == last_ci + 1 then
        consecutive = consecutive + 1
        score = score + consecutive * 3
      else
        consecutive = 1
        score = score + 1
      end
      if ci == 1 then
        score = score + 8
      end
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
    if vim.startswith(sl, ql) then
      score = score + 50
    end
    score = score - math.floor(#str / 8)
    return math.max(1, score)
  end

  return nil
end

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------

-- Every line is a fixed-width string with this exact structure (display cells):
--
--   [MARK_W][ICON_W][<--- item_budget --->][SEP_LITERAL][<-- desc_budget -->][SCROLL_W?]
--
-- The separator and description are embedded as literal characters in the line
-- string — NOT as virt_text — so their column is unconditionally stable
-- regardless of scrollbar, Neovim version, or virt_text stacking order.
--
-- MARK_W      : "▸ " / "  "  — 2 cells (selection marker area)
-- ICON_W      : icon glyph + space — always 2 display cells
-- SEP_LITERAL : " │ "  — 3 cells (space · bar · space)
-- DESC_PAD_R  : trailing space(s) after desc text before scrollbar — 1 cell
-- SCROLL_W    : 1 cell reserved for the scrollbar glyph (only when total > window_size)

local MARK_W = 2 -- "▸ "
local ICON_W = 2 -- icon glyph + trailing space
local SEP_CELLS = 3 -- " │ "
local DESC_PAD_R = 1 -- trailing space after description
local SCROLL_W = 1 -- scrollbar glyph width

-- Minimum display cells for the description column to bother showing it
local DESC_MIN_W = 6

-- Byte offset where item text starts in the line string.
-- marker_pad is ASCII (MARK_W bytes). icon bytes vary but display = ICON_W.
-- TEXT_COL is used for display arithmetic; icon byte offset is computed live.
local TEXT_COL = MARK_W + ICON_W -- = 4 display cells from left

local MAX_VISIBLE = 12
local MIN_WIDTH = 40
local MAX_ITEM_LEN = 65

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
  popup_w = 0,
  locked = false,
  gutter_hl = "NvimCmdlineCompGutter",
  -- Derived from popup_w at open(); fixed for the popup lifetime:
  item_budget = 0, -- display cells for item text
  desc_budget = 0, -- display cells for description (0 = hidden)
  has_scroll = false,
  -- Byte offsets into the rendered line string (set once in open, reused in apply_hl):
  icon_byte_start = 0,
  text_byte_start = 0, -- after icon
  sep_byte_start = 0, -- start of " │ " literal
  desc_byte_start = 0, -- start of description text
}

local kind_cache = {} ---@type table<string, CompKind>

-- ---------------------------------------------------------------------------
-- Kind helper (cached)
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
-- Layout budget computation
-- Called once in M.open(). Returns a layout table stored into state.
-- All values are in display cells.
--
-- Line structure:
--   [MARK_W][icon(ICON_W)][item_budget][SEP_CELLS?][desc_budget?][DESC_PAD_R?][SCROLL_W?]
--
-- The popup window width equals popup_w exactly.  All columns are literal
-- characters embedded in the line string; nothing is left to virt_text.
-- ---------------------------------------------------------------------------

---@return table  { item_budget, desc_budget, has_scroll }
local function compute_layout(items, popup_w, total, window_size)
  local has_scroll = total > window_size

  -- Find the widest description that will be shown
  local max_desc = 0
  for _, item in ipairs(items) do
    local k = get_kind(item:sub(1, MAX_ITEM_LEN))
    local dw = vim.api.nvim_strwidth(k.desc ~= "" and k.desc or k.label)
    if dw > max_desc then
      max_desc = dw
    end
  end

  -- Reserve scrollbar column when needed
  local scroll_reserve = has_scroll and SCROLL_W or 0

  -- Total fixed overhead on each line
  -- (MARK_W + ICON_W accounted via TEXT_COL; sep+desc+pad are right-side)
  local right_fixed = (max_desc >= DESC_MIN_W) and (SEP_CELLS + max_desc + DESC_PAD_R + scroll_reserve)
    or scroll_reserve

  local item_budget = popup_w - TEXT_COL - right_fixed

  if item_budget < 12 then
    -- Too narrow to show description; drop it, keep scrollbar only
    right_fixed = scroll_reserve
    item_budget = popup_w - TEXT_COL - right_fixed
    max_desc = 0
  end

  local desc_budget = (max_desc >= DESC_MIN_W) and max_desc or 0

  return {
    item_budget = math.max(8, item_budget),
    desc_budget = desc_budget,
    has_scroll = has_scroll,
  }
end

-- ---------------------------------------------------------------------------
-- Line builder
-- Produces fixed-width lines where every column is a literal character.
--
-- Line anatomy (all display-cell widths):
--   [MARK_W spaces][icon ICON_W][item text item_budget][" │ " SEP_CELLS][desc desc_budget][DESC_PAD_R]
--   (scrollbar glyph is rendered by render_scrollbar as a right_align virt_text
--    over the last SCROLL_W column(s) — but those cells are already blank in
--    the literal line text so nothing is displaced)
-- ---------------------------------------------------------------------------

--- Truncate `s` to at most `max_cells` display cells, appending "…" if cut.
local function trunc(s, max_cells)
  if vim.api.nvim_strwidth(s) <= max_cells then
    return s
  end
  if max_cells <= 1 then
    return "…"
  end
  local t = s
  while vim.api.nvim_strwidth(t) > max_cells - 1 do
    t = t:sub(1, -2)
  end
  return t .. "…"
end

--- Pad `s` with spaces on the right until its display width equals `w`.
local function pad_to(s, w)
  local sw = vim.api.nvim_strwidth(s)
  if sw >= w then
    return s
  end
  return s .. string.rep(" ", w - sw)
end

local function build_lines()
  local lines = {}
  local marker_pad = string.rep(" ", MARK_W)
  local item_budget = state.item_budget
  local desc_budget = state.desc_budget
  local has_desc = desc_budget > 0

  for i = state.window_start, state.window_start + state.window_size - 1 do
    local item = state.items[i + 1]
    if not item then
      break
    end

    local s = item:sub(1, MAX_ITEM_LEN)
    local k = get_kind(s)

    -- Item text: truncate then pad to exact item_budget cells
    local item_part = pad_to(trunc(s, item_budget), item_budget)

    -- Description column
    local right_part = ""
    if has_desc then
      local desc = k.desc ~= "" and k.desc or k.label
      local desc_trunc = pad_to(trunc(desc, desc_budget), desc_budget)
      right_part = " │ " .. desc_trunc .. string.rep(" ", DESC_PAD_R)
    end

    lines[#lines + 1] = marker_pad .. k.icon .. item_part .. right_part
  end

  if state.total > state.window_size then
    local last_shown = state.window_start + state.window_size
    -- Footer spans the full item column; leave description column blank
    local footer_text = ("%d – %d  of  %d"):format(
      state.window_start + 1,
      math.min(last_shown, state.total),
      state.total
    )
    local footer_item = pad_to(footer_text, item_budget)
    local footer_right = has_desc and string.rep(" ", SEP_CELLS + desc_budget + DESC_PAD_R) or ""
    lines[#lines + 1] = string.rep(" ", TEXT_COL) .. footer_item .. footer_right
  end

  return lines
end

-- ---------------------------------------------------------------------------
-- Highlight application (per row)
--
-- The separator and description are now literal characters in the line string,
-- so we simply place extmarks over their known byte ranges.
-- state.{icon,text,sep,desc}_byte_start are set once in M.open() and are
-- identical for every content row (icons differ in byte length but the item
-- text that follows is always at text_byte_start because the line was built
-- with the icon embedded).
-- ---------------------------------------------------------------------------

local function apply_hl(buf, row, item, query, kind)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line or line == "" then
    return
  end

  local is_sel = (state.selected == row)
  local llen = #line
  local R = require("custom.ui.render")
  local base_hl = "NvimCmdlineMenu"
  local match_hl = is_sel and "NvimCmdlineMenuSelMatch" or "NvimCmdlineMenuMatch"
  local icon_hl = "NvimCmdlineMenuIcon"
  local sep_hl = "NvimCmdlineSep"
  local badge_hl = kind.hl or "NvimCmdlineKindBadge"

  -- 1. Base row background (full line)
  R.set_extmark(buf, NS, row, 0, {
    end_col = llen,
    hl_group = base_hl,
    priority = 10,
  })

  -- 2. Icon highlight
  --    icon_byte_start = MARK_W (ASCII pad), icon ends at + #kind.icon bytes.
  local icon_bs = state.icon_byte_start
  local icon_be = icon_bs + #kind.icon
  if icon_be <= llen then
    R.set_extmark(buf, NS, row, icon_bs, {
      end_col = icon_be,
      hl_group = icon_hl,
      priority = 55,
    })
  end

  -- 3. Separator highlight  " │ "
  --    sep_byte_start is fixed for all content rows (computed in open()).
  if state.desc_budget > 0 then
    local sep_bs = state.sep_byte_start
    local sep_be = sep_bs + SEP_CELLS -- SEP_CELLS = 3 bytes (" │ " is ASCII+UTF8)
    -- "│" is 3 bytes (U+2502); " │ " = 1+3+1 = 5 bytes total
    local sep_actual_bytes = 1 + 3 + 1 -- " " + "│" + " "
    sep_be = sep_bs + sep_actual_bytes
    if sep_be <= llen then
      R.set_extmark(buf, NS, row, sep_bs, {
        end_col = sep_be,
        hl_group = sep_hl,
        priority = 50,
      })
    end

    -- 4. Description text highlight
    local desc_bs = state.desc_byte_start
    local desc_be = llen -- extends to end of content (before any scrollbar virt_text)
    if desc_bs < llen then
      R.set_extmark(buf, NS, row, desc_bs, {
        end_col = desc_be,
        hl_group = badge_hl,
        priority = 50,
      })
    end
  end

  -- 5. Fuzzy-match character highlights
  --    text_byte_start = MARK_W + #kind.icon (set in open() for the first item;
  --    re-derived here per-row since icon byte length can vary across kinds).
  --    MARK_W is ASCII so byte == display col.
  if query and query ~= "" then
    local tbs = MARK_W + #kind.icon -- byte start of item text for THIS kind
    local ql = query:lower()
    local qi = 1
    for ci = 1, #item do
      if qi > #ql then
        break
      end
      if item:sub(ci, ci):lower() == ql:sub(qi, qi) then
        local col = tbs + ci - 1
        if col + 1 <= llen then
          R.set_extmark(buf, NS, row, col, {
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
-- Uses its own namespace (NS_SCROLL) so it never conflicts with NS highlights.
-- ---------------------------------------------------------------------------

local NS_SCROLL = vim.api.nvim_create_namespace("nvim_cmdline_completion_scroll")

local function render_scrollbar()
  if not HAS_RIGHT_ALIGN then
    return
  end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.buf, NS_SCROLL, 0, -1)

  if state.total <= state.window_size then
    return
  end

  local wsize = state.window_size
  local total = state.total
  local ws = state.window_start
  local thumb_sz = math.max(1, math.floor(wsize * wsize / total))
  local max_start = wsize - thumb_sz
  local thumb_top = math.min(max_start, math.floor(ws / (total - wsize) * max_start))

  local R = require("custom.ui.render")
  for row = 0, wsize - 1 do
    local in_thumb = row >= thumb_top and row < thumb_top + thumb_sz
    local ch = in_thumb and "█" or "░"
    local grp = in_thumb and "NvimCmdlineScrollThumb" or "NvimCmdlineScrollTrack"
    pcall(R.set_extmark, state.buf, NS_SCROLL, row, 0, {
      virt_text = { { ch, grp } },
      virt_text_pos = "right_align",
      priority = 200,
    })
  end
end

-- ---------------------------------------------------------------------------
-- Selection marker (own namespace to avoid NS clear stomping it)
-- ---------------------------------------------------------------------------

local NS_MARKER = vim.api.nvim_create_namespace("nvim_cmdline_completion_marker")

local function render_marker()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.buf, NS_MARKER, 0, -1)
  if state.selected < 0 or state.selected >= state.window_size then
    return
  end

  local R = require("custom.ui.render")
  local row = state.selected

  -- Selection background covers only the left side of the line — from col 0
  -- up to (but NOT including) the " │ " separator.  When desc_budget > 0 the
  -- separator starts at state.sep_byte_start; otherwise it runs to end-of-line.
  local line = vim.api.nvim_buf_get_lines(state.buf, row, row + 1, false)[1] or ""
  if #line > 0 then
    -- Start after the marker pad + icon so the selection background covers
    -- only the item text, not the icon or marker gutter.
    local item = state.items[state.window_start + row + 1] or ""
    local kind = get_kind(item:sub(1, MAX_ITEM_LEN))
    local sel_start = MARK_W + #kind.icon -- byte col right after the icon
    local sel_end = (state.desc_budget > 0 and state.sep_byte_start > 0) and state.sep_byte_start or #line
    if sel_start < sel_end then
      R.set_extmark(state.buf, NS_MARKER, row, sel_start, {
        end_col = sel_end,
        hl_group = "NvimCmdlineMenuSel",
        priority = 15,
      })
    end
  end

  -- Selection marker glyph "▸ " overlaid on the marker-pad area at priority 100
  -- (highest in NS_MARKER; sits above everything including the sel background).
  R.set_extmark(state.buf, NS_MARKER, row, 0, {
    virt_text = { { "▸ ", "NvimCmdlineMenuSelMark" } },
    virt_text_pos = "overlay",
    priority = 100,
  })
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

---@param text string
---@return string[]
function M.get_completions(text)
  if type(text) ~= "string" or text == "" then
    return {}
  end

  local word = text:match("[^%s=]+$") or text
  local base = text:match("^(.*[%s=])") or ""

  local ok, items = pcall(vim.fn.getcompletion, text, "cmdline")
  if not ok or type(items) ~= "table" then
    return {}
  end

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

-- ---------------------------------------------------------------------------
-- Word cache for search completion
-- ---------------------------------------------------------------------------

local _word_cache = {}
local _last_cache_refresh = 0
local CACHE_TTL_MS = 5000

local function refresh_word_cache()
  local now = vim.uv.now()
  if now - _last_cache_refresh < CACHE_TTL_MS and #_word_cache > 0 then
    return
  end

  _word_cache = {}
  local seen = {}
  local MAX_WORDS = 500

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if #_word_cache >= MAX_WORDS then
      break
    end
    if vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "" then
      local nlines = vim.api.nvim_buf_line_count(b)
      for _, ln in ipairs(vim.api.nvim_buf_get_lines(b, 0, math.min(nlines, 500), false)) do
        if #_word_cache >= MAX_WORDS then
          break
        end
        for w in ln:gmatch("[%a_][%w_]+") do
          if #w > 3 and not seen[w] then
            seen[w] = true
            _word_cache[#_word_cache + 1] = w
          end
        end
      end
    end
  end
  _last_cache_refresh = now
end

---@param pattern string
---@return string[]
function M.get_buffer_words(pattern)
  if type(pattern) ~= "string" then
    return {}
  end
  refresh_word_cache()

  local matches = {}
  local pl = pattern:lower()
  for _, w in ipairs(_word_cache) do
    local s = fuzzy_score(w, pl)
    if s then
      matches[#matches + 1] = { word = w, score = s }
    end
  end

  if #matches > 0 then
    table.sort(matches, function(a, b)
      if a.score ~= b.score then
        return a.score > b.score
      end
      return #a.word < #b.word
    end)
    local out = {}
    for i = 1, math.min(#matches, 20) do
      out[i] = matches[i].word
    end
    return out
  end

  return {}
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
---@param gutter      integer?   (unused; kept for call-site compatibility)
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

  state.gutter_hl = (mode == "search_fwd" or mode == "search_bwd") and "NvimCmdlineCompGutterSearch"
    or "NvimCmdlineCompGutter"

  if state.prefix ~= prefix then
    kind_cache = {}
  end

  state.prefix = prefix
  state.query = query

  -- Pre-populate kind cache for width computation below
  for _, item in ipairs(items) do
    get_kind(item:sub(1, MAX_ITEM_LEN))
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

  -- Popup width: match parent cmdline window exactly
  local parent_w = MIN_WIDTH
  local popup_col = 0
  local ok_cfg, pc = pcall(vim.api.nvim_win_get_config, parent_win)
  if ok_cfg then
    if type(pc.width) == "number" then
      parent_w = pc.width
    end
    if type(pc.col) == "number" then
      popup_col = pc.col
    end
  end
  local popup_w = math.max(MIN_WIDTH, parent_w)

  -- Compute fixed layout for this popup's lifetime
  local layout = compute_layout(items, popup_w, #items, window_size)

  -- Derive byte offsets used by apply_hl.
  -- We use the icon of the first item to set icon_byte_start/text_byte_start.
  -- For kinds whose icon has a different byte length, apply_hl re-derives
  -- text_byte_start inline (tbs = MARK_W + #kind.icon) — but sep_byte_start
  -- and desc_byte_start are fixed because the line was built with item_budget
  -- padding, so the right-side columns start at the same byte every row.
  --
  -- sep_byte_start (display col) = MARK_W + ICON_W + item_budget
  -- In bytes: MARK_W (ASCII) + <icon bytes from first item> + <item text bytes>
  -- But item text is padded to item_budget DISPLAY cells, and those cells are
  -- all ASCII spaces in the padding portion, so byte count = display count.
  -- We therefore use display arithmetic directly for the right-side offsets
  -- and rely on the fact that item text (truncated + padded) fills exactly
  -- item_budget bytes of ASCII+content.
  --
  -- Safest approach: compute byte offsets from a representative built line.
  -- We pre-build one sample line and measure it.
  local sample_item = items[1]:sub(1, MAX_ITEM_LEN)
  local sample_kind = get_kind(sample_item)
  -- icon_byte_start is always MARK_W (marker pad is ASCII spaces)
  local icon_bs = MARK_W
  -- text_byte_start: after marker pad + icon bytes
  local text_bs = MARK_W + #sample_kind.icon
  -- sep_byte_start: text_bs + item_budget bytes
  -- (item text is padded to item_budget display cells; padding is ASCII spaces,
  --  and the item content itself may be multibyte but we measure the padded string)
  local sample_item_str = sample_item
  -- trunc to budget
  if vim.api.nvim_strwidth(sample_item_str) > layout.item_budget then
    while vim.api.nvim_strwidth(sample_item_str) > layout.item_budget - 1 do
      sample_item_str = sample_item_str:sub(1, -2)
    end
    sample_item_str = sample_item_str .. "…"
  end
  -- pad to budget
  local item_part_w = vim.api.nvim_strwidth(sample_item_str)
  sample_item_str = sample_item_str .. string.rep(" ", math.max(0, layout.item_budget - item_part_w))
  local sep_bs = text_bs + #sample_item_str
  -- desc_byte_start: sep_bs + byte length of " │ " = 1+3+1 = 5 bytes
  local desc_bs = sep_bs + 5 -- " │ " is 5 bytes

  local ref_row = (type(cmdline_row) == "number" and cmdline_row > 0) and cmdline_row or available_above + 1
  local popup_row = math.max(0, ref_row - (window_size + (has_footer and 1 or 0)) - 2)

  state.items = items
  state.total = #items
  state.window_start = 0
  state.window_size = window_size
  state.selected = -1
  state.global_index = -1
  state.popup_w = popup_w
  state.item_budget = layout.item_budget
  state.desc_budget = layout.desc_budget
  state.has_scroll = layout.has_scroll
  state.icon_byte_start = icon_bs
  state.text_byte_start = text_bs
  state.sep_byte_start = layout.desc_budget > 0 and sep_bs or 0
  state.desc_byte_start = layout.desc_budget > 0 and desc_bs or 0

  local lines = build_lines()

  local buf = require("custom.ui.buffer").create_raw(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win = require("custom.ui.window").open_raw(buf, false, {
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
  -- cursorline disabled: selection is drawn entirely via a full-line extmark
  -- in NS_MARKER (priority 15) so it never overwrites sep/desc highlights.
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "winblend", 10, { win = win })

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
  end

  state.selected = next_global - state.window_start
  render_marker()
  pcall(vim.api.nvim_win_set_cursor, state.win, { state.selected + 1, 0 })
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
  end

  state.selected = prev_global - state.window_start
  render_marker()
  pcall(vim.api.nvim_win_set_cursor, state.win, { state.selected + 1, 0 })
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
    apply_hl(state.buf, row, s, state.query, k)
  end

  render_marker()

  -- Footer row highlight
  if state.total > state.window_size then
    local fr = state.window_size
    local ft = vim.api.nvim_buf_get_lines(state.buf, fr, fr + 1, false)[1] or ""
    if #ft > 0 then
      require("custom.ui.render").set_extmark(state.buf, NS, fr, 0, {
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
  state.popup_w = 0
  state.item_budget = 0
  state.desc_budget = 0
  state.has_scroll = false
  state.icon_byte_start = 0
  state.text_byte_start = 0
  state.sep_byte_start = 0
  state.desc_byte_start = 0
  state.locked = false
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
