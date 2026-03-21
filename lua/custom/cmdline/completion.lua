-- nvim-cmdline/completion.lua
-- Floating completion popup with full scrolling through ALL items via Tab.
--
-- Key design:
--   state.global_index  = cursor in the full items[] list (0-based)
--   state.window_start  = index of the first visible row in items[] (0-based)
--   state.selected      = cursor within the visible window (0-based, for HL)
--   state.window_size   = number of content rows in the popup (no footer)
--
-- Tab at the last visible row slides the window forward.
-- Tab at the last item wraps back to item 0.

local M = {}

local NS = vim.api.nvim_create_namespace("nvim_cmdline_completion")

-- ---------------------------------------------------------------------------
-- Kind icons
-- ---------------------------------------------------------------------------

---@class CompKind
---@field icon  string
---@field label string

---@type table<string, CompKind>
local KINDS = {
  command = { icon = " ", label = "cmd" },
  file = { icon = " ", label = "file" },
  dir = { icon = " ", label = "dir" },
  option = { icon = " ", label = "opt" },
  help = { icon = " ", label = "help" },
  lua = { icon = " ", label = "lua" },
  shell = { icon = " ", label = "sh" },
  buffer = { icon = " ", label = "buf" },
  color = { icon = " ", label = "clr" },
  event = { icon = " ", label = "evt" },
  highlight = { icon = " ", label = "hl" },
  mapping = { icon = " ", label = "map" },
  unknown = { icon = " ", label = "" },
}
---@param item   string
---@param prefix string
---@return CompKind
local function guess_kind(item, prefix)
  if item:sub(-1) == "/" or item:sub(-1) == "\\" then
    return KINDS.dir
  end
  if item:match("%.[a-zA-Z0-9]+$") then
    return KINDS.file
  end
  if prefix:match("^%s*setl?") then
    return KINDS.option
  end
  if prefix:match("^%s*hi") then
    return KINDS.highlight
  end
  if prefix:match("^%s*[nvxioc]?n?o?r?e?map") then
    return KINDS.mapping
  end
  if prefix:match("^%s*colou?rscheme") then
    return KINDS.color
  end
  if prefix:match("^%s*au") then
    return KINDS.event
  end
  if prefix:match("^%s*he?l?p?%s") then
    return KINDS.help
  end
  if prefix:match("^%s*lua") then
    return KINDS.lua
  end
  if prefix:match("^%s*!") then
    return KINDS.shell
  end
  if item:match("^[%a_][%w_]*$") and #item <= 24 then
    return KINDS.buffer
  end
  return KINDS.command
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local state = {
  win = nil, ---@type integer|nil
  buf = nil, ---@type integer|nil
  items = {}, ---@type string[]   full list
  total = 0, -- #items
  window_start = 0, -- 0-based index of first visible row in items[]
  window_size = 0, -- number of content rows (excluding footer)
  selected = -1, -- 0-based position within the visible window (-1 = none)
  global_index = -1, -- 0-based position within items[] (-1 = none)
  query = "",
  prefix = "",
  max_item_w = 0, -- cached max item width for stable column layout
  popup_w = 0, -- cached window width
  locked = false, -- when true, open() is a no-op (Tab cycling in progress)
}

local MAX_VISIBLE = 10
local MIN_WIDTH = 30
local MAX_ITEM_LEN = 46
local COL_TEXT = 4 -- "  " (2) + icon (2) = 4 before item text

-- ---------------------------------------------------------------------------
-- Highlight helper
-- ---------------------------------------------------------------------------

---@param buf    integer
---@param row    integer  0-indexed buffer row
---@param item   string   raw item text (no padding/icon)
---@param query  string
---@param kind   CompKind
---@param is_sel boolean
local function apply_hl(buf, row, item, query, kind, is_sel)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local llen = #line
  if llen == 0 then
    return
  end

  local base_hl = is_sel and "NvimCmdlineMenuSel" or "NvimCmdlineMenu"
  local match_hl = is_sel and "NvimCmdlineMenuSelMatch" or "NvimCmdlineMenuMatch"
  local hint_hl = is_sel and "NvimCmdlineMenuSelHint" or "NvimCmdlineMenuHint"

  -- Base background
  vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
    end_col = llen,
    hl_group = base_hl,
    priority = 10,
  })

  -- Selection arrow (overlay on leading 2 spaces)
  if is_sel then
    vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
      virt_text = { { "> ", "NvimCmdlineMenuMark" } },
      virt_text_pos = "overlay",
      priority = 40,
    })
  end

  -- Right-aligned kind label
  if kind.label ~= "" then
    vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
      virt_text = { { " " .. kind.label .. " ", hint_hl } },
      virt_text_pos = "eol",
      priority = 15,
    })
  end

  -- Fuzzy match highlights
  if query ~= "" then
    local qi = 1
    for ci = 1, #item do
      if qi > #query then
        break
      end
      if item:sub(ci, ci):lower() == query:sub(qi, qi):lower() then
        local col = COL_TEXT + ci - 1
        if col + 1 <= llen then
          vim.api.nvim_buf_set_extmark(buf, NS, row, col, {
            end_col = col + 1,
            hl_group = match_hl,
            priority = 25,
          })
        end
        qi = qi + 1
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Window content builder
-- ---------------------------------------------------------------------------

---Build the text lines for the current window slice and footer.
---@return string[]  lines to write into the buffer
local function build_lines()
  local lines = {}
  local pad_w = state.max_item_w

  for i = state.window_start, state.window_start + state.window_size - 1 do
    local item = state.items[i + 1] -- items is 1-based
    if not item then
      break
    end
    local s = item:sub(1, MAX_ITEM_LEN)
    local k = guess_kind(s, state.prefix)
    local pad = pad_w - #s
    lines[#lines + 1] = "  " .. k.icon .. s .. string.rep(" ", math.max(0, pad) + 2)
  end

  -- Footer: position indicator  e.g. "  [3–10 / 15]  "
  local last_visible = state.window_start + state.window_size - 1
  if state.total > state.window_size then
    lines[#lines + 1] = ("  [%d–%d / %d]  "):format(
      state.window_start + 1,
      math.min(last_visible + 1, state.total),
      state.total
    )
  end

  return lines
end

---Rewrite the buffer content and refresh highlights.
---Called whenever window_start changes (scrolling).
local function rebuild_window()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = build_lines()

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

  -- Update window height if it changed (e.g. footer appeared/disappeared)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_set_config, state.win, { height = #lines })
  end

  M._redraw_highlights()
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function M.get_completions(text)
  if type(text) ~= "string" or text == "" then
    return {}
  end
  local ok, result = pcall(vim.fn.getcompletion, text, "cmdline")
  if not ok or type(result) ~= "table" then
    return {}
  end
  return result
end

---@param pattern string
---@return string[]
function M.get_buffer_words(pattern)
  if type(pattern) ~= "string" then
    return {}
  end
  local words, seen = {}, {}
  local pl = pattern:lower()
  local MAX_WORDS = 200

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if #words >= MAX_WORDS then
      break
    end
    if not (vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_is_valid(b)) then
      goto continue
    end
    local ok_bt, bt = pcall(vim.api.nvim_get_option_value, "buftype", { buf = b })
    if ok_bt and bt ~= "" then
      goto continue
    end

    local nlines = vim.api.nvim_buf_line_count(b)
    for _, ln in ipairs(vim.api.nvim_buf_get_lines(b, 0, math.min(nlines, 1000), false)) do
      if #words >= MAX_WORDS then
        break
      end
      for w in ln:gmatch("[%a_][%w_]+") do
        if not seen[w] and (pl == "" or w:lower():find(pl, 1, true)) then
          seen[w] = true
          words[#words + 1] = w
        end
      end
    end
    ::continue::
  end

  table.sort(words, function(a, b)
    local as = vim.startswith(a:lower(), pl)
    local bs = vim.startswith(b:lower(), pl)
    if as ~= bs then
      return as
    end
    return #a < #b
  end)
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
---@param cmdline_row integer?  stable target row (animation-independent)
function M.open(parent_win, items, query, prefix, cmdline_row)
  if state.locked then
    return
  end
  M.close()
  if #items == 0 then
    return
  end

  prefix = type(prefix) == "string" and prefix or ""
  query = type(query) == "string" and query or ""

  -- Compute max item width over ALL items so columns stay stable while scrolling
  local max_item = MIN_WIDTH - COL_TEXT
  for _, item in ipairs(items) do
    max_item = math.max(max_item, math.min(#item, MAX_ITEM_LEN))
  end

  -- Available rows above the cmdline
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

  -- Window size: leave room for 2 border rows + 1 footer row
  local window_size = math.max(
    1,
    math.min(
      #items,
      MAX_VISIBLE,
      available_above - 3 -- 2 border + 1 footer
    )
  )
  local has_footer = #items > window_size

  local popup_h = window_size + (has_footer and 1 or 0)
  local content_w = COL_TEXT + max_item + 2

  -- Column alignment with cmdline
  local popup_col = 0
  local popup_w = content_w
  local ok_cfg, pc = pcall(vim.api.nvim_win_get_config, parent_win)
  if ok_cfg then
    popup_col = type(pc.col) == "number" and pc.col or 0
    popup_w = type(pc.width) == "number" and math.max(content_w, pc.width) or content_w
  end

  -- Row: always above the cmdline
  local ref_row = (type(cmdline_row) == "number" and cmdline_row > 0) and cmdline_row or available_above + 1
  local popup_row = math.max(0, ref_row - popup_h - 2)

  -- Initialise state BEFORE building lines (build_lines reads state)
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

  -- Buffer
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
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    zindex = 210,
    focusable = false,
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NvimCmdlineMenu,FloatBorder:NvimCmdlineMenuBorder",
    { win = win }
  )
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "winblend", 8, { win = win })

  state.buf = buf
  state.win = win

  M._redraw_highlights()
end

---Advance the selection by one item (Tab).
---Scrolls the visible window when the cursor exits the bottom.
---Wraps from the last item back to the first.
---@return string|nil  the selected item text
function M.select_next()
  if not M.is_open() then
    return nil
  end

  local next_global
  if state.global_index < 0 then
    next_global = 0
  else
    next_global = (state.global_index + 1) % state.total
  end
  state.global_index = next_global

  -- Scroll window forward if cursor is past the bottom
  if next_global >= state.window_start + state.window_size then
    if next_global == 0 then
      -- Wrapped around to the start — reset window
      state.window_start = 0
    else
      state.window_start = next_global - state.window_size + 1
    end
    rebuild_window()
  elseif next_global < state.window_start then
    -- Cursor is before the window (can happen after a wrap)
    state.window_start = 0
    rebuild_window()
  else
    -- Cursor is still inside the current window — just redraw highlights
    state.selected = next_global - state.window_start
    M._redraw_highlights()
  end

  state.selected = next_global - state.window_start
  return state.items[next_global + 1]
end

---Move the selection back by one item (S-Tab).
---Scrolls the visible window when the cursor exits the top.
---Wraps from the first item to the last.
---@return string|nil
function M.select_prev()
  if not M.is_open() then
    return nil
  end

  local prev_global
  if state.global_index <= 0 then
    prev_global = state.total - 1
  else
    prev_global = state.global_index - 1
  end
  state.global_index = prev_global

  -- Scroll window backward if cursor is before the top
  if prev_global < state.window_start then
    if prev_global == state.total - 1 then
      -- Wrapped to the last item — show the last window
      state.window_start = math.max(0, state.total - state.window_size)
    else
      state.window_start = prev_global
    end
    rebuild_window()
  elseif prev_global >= state.window_start + state.window_size then
    -- Cursor is past the window (wrap from top to bottom)
    state.window_start = math.max(0, state.total - state.window_size)
    rebuild_window()
  else
    state.selected = prev_global - state.window_start
    M._redraw_highlights()
  end

  state.selected = prev_global - state.window_start
  return state.items[prev_global + 1]
end

---Redraw all extmarks without touching buffer text.
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
    local k = guess_kind(s, state.prefix)
    local is_sel = row == state.selected
    apply_hl(state.buf, row, s, state.query, k, is_sel)
  end

  -- Footer highlight (last row when present)
  if state.total > state.window_size then
    local fr = state.window_size
    local ft = vim.api.nvim_buf_get_lines(state.buf, fr, fr + 1, false)[1] or ""
    if #ft > 0 then
      vim.api.nvim_buf_set_extmark(state.buf, NS, fr, 0, {
        end_col = #ft,
        hl_group = "NvimCmdlineMenuHint",
        priority = 10,
      })
    end
  end
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
end

---@return boolean
function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

---@return integer|nil
function M.get_win()
  return state.win
end

---@return integer
function M.count()
  return state.total
end

return M
