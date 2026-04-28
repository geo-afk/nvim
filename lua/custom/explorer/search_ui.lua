-- custom/explorer/search_ui.lua
--
-- The search header is embedded directly in S.buf as the first 3 lines.
-- No separate window or buffer is used.  S.win shows everything.
--
-- Buffer layout (1-based lines / 0-based rows):
--
--   row 0  line 1  ╭──── Filter Files ────╮   top border
--   row 1  line 2  │ 󰍉  <query>       n/m │   input row  ← cursor here when active
--   row 2  line 3  ╰──────────────────────╯   bottom border
--   row 3  line 4  S.items[1]
--   row 4  line 5  S.items[2]
--   …
--
-- lock_tree_view() pins topline to HEADER_LINES+1 (line 4) so the header
-- is always visible regardless of how far the user scrolls.
--
-- When search is active:
--   • S.buf is made modifiable
--   • cursor is placed on line 2 (INPUT_LNUM) of S.win and insert starts
--   • no window switch occurs — focus stays in S.win the whole time

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")

local api = vim.api
local fn = vim.fn

local M = {}

-- ── Visual constants ──────────────────────────────────────────────────────

local BORDER_CHAR = "│"
local BORDER_CHAR_BYTES = #BORDER_CHAR -- 3 bytes (UTF-8 E2 94 82)

local SEARCH_ICON = "󰍉"
local SEARCH_ICON_BYTES = #SEARCH_ICON -- 4 bytes

local PROMPT_GAP = "  " -- two spaces after icon

-- Full prefix on the input row:  │ 󰍉
-- [│:3][space:1][icon:4][gap:2] = 10 bytes
local INPUT_PREFIX = BORDER_CHAR .. " " .. SEARCH_ICON .. PROMPT_GAP
local INPUT_PREFIX_BYTES = #INPUT_PREFIX -- 10

local ICON_BYTE_OFFSET = BORDER_CHAR_BYTES + 1

local PLACEHOLDER = "Filter files..."
local TITLE = " Filter Files "

-- ── Public constants ──────────────────────────────────────────────────────

M.INPUT_PREFIX = INPUT_PREFIX
M.INPUT_PREFIX_BYTES = INPUT_PREFIX_BYTES

-- Header occupies the first 3 lines of S.buf.
M.HEADER_LINES = 3

M.INPUT_ROW = 1 -- 0-based row of the input line
M.INPUT_LNUM = 2 -- 1-based line number of the input line
M.ITEM_ROW_OFFSET = 3 -- row_for_item(i) = ITEM_ROW_OFFSET + i - 1

local BOTTOM_ROW = 2 -- 0-based row of the bottom border

-- ── Index helpers ─────────────────────────────────────────────────────────

function M.line_for_item(index)
  return M.HEADER_LINES + index
end
function M.row_for_item(index)
  return M.ITEM_ROW_OFFSET + index - 1
end

function M.item_index_from_line(line)
  local idx = line - M.HEADER_LINES
  return idx >= 1 and idx or nil
end

function M.spacer_lines()
  local t = {}
  for _ = 1, M.HEADER_LINES do
    t[#t + 1] = ""
  end
  return t
end

-- ── Scroll / cursor lock ──────────────────────────────────────────────────
--
-- Called after every paint.  Ensures:
--   1. topline >= HEADER_LINES + 1  → header is never scrolled off-screen
--   2. cursor is inside the item zone (lines HEADER_LINES+1 .. HEADER_LINES+#items)
--
-- When all content fits in the window we skip the topline manipulation to
-- avoid the WinScrolled feedback loop.

function M.lock_tree_view()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end

  local n_lines = (S.buf and api.nvim_buf_is_valid(S.buf)) and api.nvim_buf_line_count(S.buf) or M.HEADER_LINES
  local win_h = api.nvim_win_get_height(S.win)

  if n_lines > win_h then
    api.nvim_win_call(S.win, function()
      local view = fn.winsaveview()
      local min_top = M.HEADER_LINES + 1
      if view.topline < min_top then
        view.topline = min_top
        fn.winrestview(view)
      end
    end)
  end

  -- Clamp cursor into the item zone
  local item_count = #S.items
  if item_count == 0 then
    return
  end
  local line = api.nvim_win_get_cursor(S.win)[1]
  local min_line = M.HEADER_LINES + 1
  local max_line = M.HEADER_LINES + item_count
  if line < min_line then
    pcall(api.nvim_win_set_cursor, S.win, { min_line, 0 })
  elseif line > max_line then
    pcall(api.nvim_win_set_cursor, S.win, { max_line, 0 })
  end
end

-- ── Width helper ──────────────────────────────────────────────────────────

local function win_width()
  if S.win and api.nvim_win_is_valid(S.win) then
    return math.max(api.nvim_win_get_width(S.win), 10)
  end
  return 10
end

-- ── Border builders ───────────────────────────────────────────────────────

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
  local left = math.floor((inner - label_w) / 2)
  local right = inner - label_w - left
  return "╭" .. ("─"):rep(left) .. label .. ("─"):rep(right) .. "╮"
end

local function build_bottom_border(width)
  return "╰" .. ("─"):rep(math.max(width - 2, 0)) .. "╯"
end

-- ── Text helpers ──────────────────────────────────────────────────────────

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

-- ── No-op window lifecycle (callers still call these; now they do nothing) ─

function M.ensure_window()
  -- The header lives in S.buf / S.win — nothing to create.
  return S.win, S.buf
end

function M.close()
  -- Nothing to close.
end

-- ── Border highlight resolver ─────────────────────────────────────────────

local function resolve_border_hl(is_active, has_filter)
  if is_active then
    return "ExplorerSearchBorderActive"
  end
  if has_filter then
    return "ExplorerSearchBorderFilter"
  end
  return "ExplorerSearchBorder"
end

-- ── Right-side count chunks ───────────────────────────────────────────────

local function right_chunks(is_active, has_filter, total, cursor)
  local show_count = cfg.get().search_count and has_filter
  local border_hl = resolve_border_hl(is_active, has_filter)

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

-- ── Layout maths ──────────────────────────────────────────────────────────

local _prefix_display_w = nil -- cached once

local function text_area_info(width, count_display_w)
  if not _prefix_display_w then
    _prefix_display_w = fn.strdisplaywidth(INPUT_PREFIX)
  end
  local area_w = math.max(width - _prefix_display_w - count_display_w, 0)
  return INPUT_PREFIX_BYTES, area_w
end

-- ── Paint helpers ─────────────────────────────────────────────────────────

local function paint_top_border(buf, lines, border_hl)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })
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
  -- 2. Left border │
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = BORDER_CHAR_BYTES,
    hl_group = border_hl,
    priority = 15,
  })
  -- 3. Search icon
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, ICON_BYTE_OFFSET, {
    end_col = ICON_BYTE_OFFSET + SEARCH_ICON_BYTES,
    hl_group = icon_hl,
    priority = 20,
  })

  local text_byte_start, area_w = text_area_info(width, count_w)

  -- 4a. Placeholder
  if input_line == INPUT_PREFIX then
    local ph_w = fn.strdisplaywidth(PLACEHOLDER)
    local pad_left = math.max(math.floor((area_w - ph_w) / 2), 0)
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      virt_text = { { (" "):rep(pad_left) .. PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  -- 4b. Active filter text highlight
  elseif has_filter and not is_active and input_line_bytes > INPUT_PREFIX_BYTES then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      end_row = M.INPUT_ROW,
      end_col = input_line_bytes,
      hl_group = "ExplorerSearchActiveText",
      priority = 60,
    })
  end

  -- 5. Right-aligned count + closing │
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    virt_text = chunks,
    virt_text_pos = "right_align",
    priority = 100,
  })
end

local function paint_bottom_border(buf, border_hl)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, BOTTOM_ROW, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })
end

-- ── Main paint entry point ────────────────────────────────────────────────

function M.paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local lines = M.header_lines(S.filter)

  -- Write header rows into S.buf (modifiable already set by caller when active)
  local was_modifiable = vim.bo[buf].modifiable
  if not was_modifiable then
    api.nvim_set_option_value("modifiable", true, { buf = buf })
  end
  api.nvim_buf_set_lines(buf, 0, M.HEADER_LINES, false, lines)
  if not was_modifiable and not S.search_active then
    api.nvim_set_option_value("modifiable", false, { buf = buf })
  end

  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local is_active = S.search_active
  local has_filter = S.filter ~= nil and S.filter ~= ""
  local border_hl = resolve_border_hl(is_active, has_filter)
  local chunks = right_chunks(is_active, has_filter, #S.items, S._search_cursor)

  paint_top_border(buf, lines, border_hl)
  paint_input_row(buf, lines, is_active, has_filter, chunks)
  paint_bottom_border(buf, border_hl)

  if not is_active then
    M.lock_tree_view()
  end
end

return M
