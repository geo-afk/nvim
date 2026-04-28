local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")

local api = vim.api
local fn = vim.fn

local M = {}

-- ---------------------------------------------------------------------------
-- Visual constants — snacks-inspired style
--
-- Layout of the 3-line header:
--
--   ╭────────────── Filter Files ───────────────╮   ← top border, title centred
--   │ 󰍉  <query text or centred placeholder>  n │   ← input row, fully boxed
--   ╰───────────────────────────────────────────╯   ← bottom border
--
-- The input row carries explicit │ on both sides so the box is fully closed.
-- Left │ is written into the buffer line; right │ is a right-aligned virt_text.
-- ---------------------------------------------------------------------------

local BORDER_CHAR = "│"
local BORDER_CHAR_BYTES = #BORDER_CHAR -- 3 bytes (UTF-8: E2 94 82)

local SEARCH_ICON = "󰍉"
local SEARCH_ICON_BYTES = #SEARCH_ICON -- 4 bytes (UTF-8 Nerd Font glyph)

local PROMPT_GAP = "  " -- two spaces between icon and text

-- Full prefix written into every input row:   │ 󰍉
-- Byte layout: [│:3][space:1][icon:4][gap:2] = 10 bytes total
local INPUT_PREFIX = BORDER_CHAR .. " " .. SEARCH_ICON .. PROMPT_GAP
local INPUT_PREFIX_BYTES = #INPUT_PREFIX -- 10

-- Byte offset where the icon starts inside INPUT_PREFIX.
-- Used to place the icon highlight without hard-coding a number.
local ICON_BYTE_OFFSET = BORDER_CHAR_BYTES + 1 -- +1 for the literal space

local PLACEHOLDER = "Filter files..."
local TITLE = " Filter Files " -- flanking spaces become border dashes

-- ---------------------------------------------------------------------------
-- Public surface consumed by other modules
-- ---------------------------------------------------------------------------

M.INPUT_PREFIX = INPUT_PREFIX
-- The search header lives entirely in S.search_win / S.search_buf (a separate
-- split window above the tree).  The tree buffer S.buf has NO header lines —
-- items start at line 1 (row 0).  HEADER_LINES = 0 keeps all coordinate
-- helpers correct without changing any call-sites.
M.HEADER_LINES = 0

-- These constants describe the layout inside S.search_buf, not S.buf.
M.INPUT_ROW = 1
M.INPUT_LNUM = 2
M.ITEM_ROW_OFFSET = 0 -- row_for_item(i) = i - 1

local SEARCH_BUF_LINES = 3
local BOTTOM_BORDER_ROW = 2

-- ---------------------------------------------------------------------------
-- Index helpers  (operate on S.buf coordinates)
-- ---------------------------------------------------------------------------

function M.line_for_item(index)
  return index
end -- 1-based
function M.row_for_item(index)
  return index - 1
end -- 0-based

function M.item_index_from_line(line)
  return line >= 1 and line or nil
end

-- No spacer lines — items start at line 1 of S.buf.
function M.spacer_lines()
  return {}
end

-- ---------------------------------------------------------------------------
-- Highlight resolver — single source of truth for border highlight group names
-- ---------------------------------------------------------------------------

local function resolve_border_hl(is_active, has_filter)
  if is_active then
    return "ExplorerSearchBorderActive"
  end
  if has_filter then
    return "ExplorerSearchBorderFilter"
  end
  return "ExplorerSearchBorder"
end

-- ---------------------------------------------------------------------------
-- Window / buffer guards
-- ---------------------------------------------------------------------------

local function has_search_window()
  return S.search_win and api.nvim_win_is_valid(S.search_win)
end

local function safe_set_win(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end
  local ok, err = pcall(api.nvim_set_current_win, win)
  if not ok then
    vim.notify("search_ui: cannot focus window: " .. tostring(err), vim.log.levels.WARN)
  end
end

-- ---------------------------------------------------------------------------
-- Tree-view cursor / scroll locking
-- ---------------------------------------------------------------------------

function M.lock_tree_view()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end

  local item_count = #S.items
  if item_count == 0 then
    return
  end

  local line = api.nvim_win_get_cursor(S.win)[1]
  local min_line = 1
  local max_line = item_count

  if line < min_line then
    pcall(api.nvim_win_set_cursor, S.win, { min_line, 0 })
  elseif line > max_line then
    pcall(api.nvim_win_set_cursor, S.win, { max_line, 0 })
  end
end

-- ---------------------------------------------------------------------------
-- Width helpers
--
-- NOTE: win_width() reads S.win (the tree window), not S.search_win.
-- The search bar is a horizontal split of the same column, so it always
-- shares the identical display width — no separate query needed.
-- ---------------------------------------------------------------------------

local function win_width()
  if S.win and api.nvim_win_is_valid(S.win) then
    return math.max(api.nvim_win_get_width(S.win), 10)
  end
  return 10
end

-- Rounded top border with a centred title.
-- Truncates the title with "…" when the window is too narrow.
local function build_top_border(width, title)
  local inner = math.max(width - 2, 0)
  local label = title or ""
  local label_w = fn.strdisplaywidth(label)

  if label_w == 0 or inner == 0 then
    return "╭" .. ("─"):rep(inner) .. "╮"
  end

  if label_w > inner then
    label = fn.strcharpart(label, 0, math.max(inner - 1, 0)) .. "…"
    label_w = fn.strdisplaywidth(label)
  end

  local left_dashes = math.floor((inner - label_w) / 2)
  local right_dashes = inner - label_w - left_dashes
  return "╭" .. ("─"):rep(left_dashes) .. label .. ("─"):rep(right_dashes) .. "╮"
end

local function build_bottom_border(width)
  return "╰" .. ("─"):rep(math.max(width - 2, 0)) .. "╯"
end

-- ---------------------------------------------------------------------------
-- Text helpers
-- ---------------------------------------------------------------------------

function M.line_text(filter)
  return INPUT_PREFIX .. (filter or "")
end

function M.header_lines(filter)
  local w = win_width()
  return {
    build_top_border(w, TITLE),
    M.line_text(filter),
    build_bottom_border(w),
  }
end

function M.strip_prefix(raw)
  if raw:sub(1, INPUT_PREFIX_BYTES) == INPUT_PREFIX then
    return raw:sub(INPUT_PREFIX_BYTES + 1)
  end
  return raw
end

-- ---------------------------------------------------------------------------
-- Right-side count + closing │
-- All state is passed in explicitly — no hidden global reads.
-- ---------------------------------------------------------------------------

local function right_chunks(is_active, has_filter, total, cursor)
  local show_count = cfg.get().search_count and has_filter
  local border_hl = resolve_border_hl(is_active, has_filter)

  -- When no count is shown, the chunk still ends with " │" so the right
  -- border column never shifts depending on whether a count is visible.
  if not show_count then
    return { { " │", border_hl } }
  end

  local label, count_hl
  if is_active then
    count_hl = "ExplorerSearchCountActive"
    if total == 0 then
      label = " 0 results "
    else
      local cur = cursor or 0
      label = cur > 0 and (" " .. cur .. "/" .. total .. " ") or (" " .. total .. " ")
    end
  else
    count_hl = "ExplorerSearchCount"
    label = total == 0 and " 0 results " or (" " .. total .. (total == 1 and " result " or " results "))
  end

  return {
    { label, count_hl },
    { "│", border_hl },
  }
end

-- ---------------------------------------------------------------------------
-- Buffer / window lifecycle (both idempotent)
-- ---------------------------------------------------------------------------

local function ensure_buf()
  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    return S.search_buf
  end

  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, buf, "explorer-search://")

  local bo = vim.bo[buf]
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.buflisted = false
  bo.swapfile = false
  bo.filetype = "explorer_search"
  bo.modifiable = false

  S.search_buf = buf
  return buf
end

local function apply_win_opts()
  if not has_search_window() then
    return
  end
  local wo = vim.wo[S.search_win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.wrap = false
  wo.spell = false
  wo.list = false
  wo.cursorline = false
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.winfixheight = true
  wo.winhl = "Normal:ExplorerNormal,WinBar:ExplorerNormal,WinBarNC:ExplorerNormal"
end

local function ensure_win(buf)
  if has_search_window() then
    api.nvim_win_set_buf(S.search_win, buf)
    apply_win_opts()
    return S.search_win
  end

  -- Create the search split above the tree window.
  -- We must restore focus to wherever the user was (prev_win) once done —
  -- leaving focus on the search split or the tree window would break editing.
  local prev_win = api.nvim_get_current_win()
  safe_set_win(S.win)
  vim.cmd("noautocmd keepalt leftabove " .. SEARCH_BUF_LINES .. "split")
  S.search_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(S.search_win, buf)
  pcall(api.nvim_win_set_height, S.search_win, SEARCH_BUF_LINES)
  apply_win_opts()

  -- Always return focus to prev_win.  If prev_win was the tree (S.win),
  -- focus goes back there; if it was an editor window it goes there.
  if prev_win and api.nvim_win_is_valid(prev_win) then
    pcall(api.nvim_set_current_win, prev_win)
  end

  return S.search_win
end

function M.ensure_window()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil, nil
  end
  local buf = ensure_buf()
  local win = ensure_win(buf)
  return win, buf
end

-- ---------------------------------------------------------------------------
-- Close
-- ---------------------------------------------------------------------------

function M.close()
  if S.search_win and api.nvim_win_is_valid(S.search_win) then
    pcall(api.nvim_win_close, S.search_win, true)
  end
  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    pcall(api.nvim_buf_delete, S.search_buf, { force = true })
  end
  S.search_win = nil
  S.search_buf = nil
end

-- ---------------------------------------------------------------------------
-- Layout maths
--
-- Returns:
--   text_byte_start  – byte column where user text begins in the input line
--   area_w           – display columns available for user text / placeholder
--
-- The left side of the input row occupies:
--   │(1) + space(1) + icon(w) + gap(2)  cells
-- which equals fn.strdisplaywidth(INPUT_PREFIX) in total.
-- The right side is occupied by the count + │ chunk passed in.
-- ---------------------------------------------------------------------------

local function text_area_info(width, count_display_w)
  local prefix_w = fn.strdisplaywidth(INPUT_PREFIX)
  local area_w = math.max(width - prefix_w - count_display_w, 0)
  return INPUT_PREFIX_BYTES, area_w
end

-- ---------------------------------------------------------------------------
-- Paint helpers — one function per visual region of the header
-- ---------------------------------------------------------------------------

local function paint_top_border(buf, lines, border_hl)
  -- Full-row border colour
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })

  -- Overlay a distinct highlight on the title text inside the dashes.
  local top_line = lines[1] or ""
  local title_pos = top_line:find(TITLE, 1, true)
  if title_pos then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, title_pos - 1, {
      end_col = title_pos - 1 + #TITLE,
      hl_group = "ExplorerSearchTitle",
      priority = 20,
    })
  end
end

local function paint_input_row(buf, lines, is_active, has_filter, chunks)
  local bg_hl = is_active and "ExplorerSearchBgActive" or "ExplorerSearchBg"
  local icon_hl = is_active and "ExplorerSearchIconActive" or "ExplorerSearchIcon"
  local border_hl = resolve_border_hl(is_active, has_filter)

  local width = win_width()
  local input_line = lines[M.INPUT_LNUM] or ""
  local input_line_bytes = #input_line

  -- Measure the right-side chunks so we can size the text area correctly.
  local count_label = ""
  for _, chunk in ipairs(chunks) do
    count_label = count_label .. chunk[1]
  end
  local count_w = fn.strdisplaywidth(count_label)

  -- 1. Full-row background
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = -1,
    hl_group = bg_hl,
    hl_eol = true,
    priority = 5,
  })

  -- 2. Left border character │  (matches the right-side │ from right_chunks)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = BORDER_CHAR_BYTES,
    hl_group = border_hl,
    priority = 15,
  })

  -- 3. Search icon  (starts after │ + the literal space that follows it)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, ICON_BYTE_OFFSET, {
    end_col = ICON_BYTE_OFFSET + SEARCH_ICON_BYTES,
    hl_group = icon_hl,
    priority = 20,
  })

  local text_byte_start, area_w = text_area_info(width, count_w)

  -- 4a. Centred placeholder when the input is empty
  if input_line == INPUT_PREFIX then
    local ph_w = fn.strdisplaywidth(PLACEHOLDER)
    local pad_left = math.max(math.floor((area_w - ph_w) / 2), 0)

    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      virt_text = { { string.rep(" ", pad_left) .. PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })

  -- 4b. Highlight the stored query when inactive but a filter exists
  elseif has_filter and not is_active and input_line_bytes > INPUT_PREFIX_BYTES then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      end_row = M.INPUT_ROW,
      end_col = input_line_bytes,
      hl_group = "ExplorerSearchActiveText",
      priority = 60,
    })
  end

  -- 5. Right-aligned count label + closing │
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    virt_text = chunks,
    virt_text_pos = "right_align",
    priority = 100,
  })
end

local function paint_bottom_border(buf, border_hl)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, BOTTOM_BORDER_ROW, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })
end

-- ---------------------------------------------------------------------------
-- Paint — main entry point
-- ---------------------------------------------------------------------------

function M.paint()
  local _, buf = M.ensure_window()
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local lines = M.header_lines(S.filter)

  api.nvim_set_option_value("modifiable", true, { buf = buf })
  api.nvim_buf_set_lines(buf, 0, SEARCH_BUF_LINES, false, lines)
  if not S.search_active then
    api.nvim_set_option_value("modifiable", false, { buf = buf })
  end

  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  -- Snapshot shared state once so all helpers see a consistent picture.
  local is_active = S.search_active
  local has_filter = S.filter ~= nil and S.filter ~= ""
  local border_hl = resolve_border_hl(is_active, has_filter)
  local chunks = right_chunks(is_active, has_filter, #S.items, S._search_cursor)

  paint_top_border(buf, lines, border_hl)
  paint_input_row(buf, lines, is_active, has_filter, chunks)
  paint_bottom_border(buf, border_hl)

  -- Avoid clobbering the tree cursor on every keypress during active input.
  if not is_active then
    M.lock_tree_view()
  end
end

return M
