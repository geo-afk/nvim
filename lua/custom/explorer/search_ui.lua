-- custom/explorer/search_ui.lua

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")

local api = vim.api
local fn = vim.fn

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────

local BORDER_TL = "╭"
local BORDER_TR = "╮"
local BORDER_BL = "╰"
local BORDER_BR = "╯"
local BORDER_H = "─"
local BORDER_V = "│"
local BORDER_V_BYTES = #BORDER_V -- 3

local SEARCH_ICON = "󰍉 "
local SEARCH_ICON_BYTES = #SEARCH_ICON -- 7 bytes

local INPUT_PREFIX = BORDER_V .. " " .. SEARCH_ICON
local INPUT_PREFIX_BYTES = #INPUT_PREFIX -- 11
local INPUT_PREFIX_DISPLAY_W = fn.strdisplaywidth(INPUT_PREFIX)

M.INPUT_PREFIX = INPUT_PREFIX
M.INPUT_PREFIX_BYTES = INPUT_PREFIX_BYTES

local PLACEHOLDER = "Filter files…"
local TITLE = " Files "

-- ── Public coordinate constants ───────────────────────────────────────────

M.SEARCH_WIN_HEIGHT = 3 -- height of the separate search window
M.HEADER_LINES = 0 -- tree buffer has no header lines (items start at line 1)

-- these refer to rows inside the search window (0‑based)
M.INPUT_ROW = 1
M.INPUT_LNUM = 2
M.BOTTOM_ROW = 2

-- ── Index helpers ─────────────────────────────────────────────────────────

function M.line_for_item(index)
  return index -- 1‑based line number in tree buffer
end

function M.row_for_item(index)
  return index - 1 -- 0‑based row in tree buffer
end

function M.item_index_from_line(line)
  local idx = line
  return idx >= 1 and idx or nil
end

function M.spacer_lines()
  return {} -- no spacers in tree buffer
end

-- ── Scroll / cursor lock ──────────────────────────────────────────────────

function M.lock_tree_view()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end

  local n_lines = (S.buf and api.nvim_buf_is_valid(S.buf)) and api.nvim_buf_line_count(S.buf) or 0
  if n_lines == 0 then
    return
  end

  local win_h = api.nvim_win_get_height(S.win)
  local item_count = #S.items
  if item_count == 0 then
    return
  end

  -- cursor must stay inside the range [1, item_count]
  local line = api.nvim_win_get_cursor(S.win)[1]
  if line < 1 then
    pcall(api.nvim_win_set_cursor, S.win, { 1, 0 })
  elseif line > item_count then
    pcall(api.nvim_win_set_cursor, S.win, { item_count, 0 })
  end
end

-- ── Width helpers ─────────────────────────────────────────────────────────

local function win_width()
  if S.win and api.nvim_win_is_valid(S.win) then
    return math.max(api.nvim_win_get_width(S.win), 10)
  end
  return 10
end

-- ── Border builders ───────────────────────────────────────────────────────

local function top_border(width, title)
  local inner = math.max(width - 2, 0)
  local label = title or ""
  local label_w = fn.strdisplaywidth(label)
  if label_w == 0 or inner == 0 then
    return BORDER_TL .. BORDER_H:rep(inner) .. BORDER_TR
  end
  if label_w > inner then
    label = fn.strcharpart(label, 0, math.max(inner - 1, 0)) .. "…"
    label_w = fn.strdisplaywidth(label)
  end
  local left = math.floor((inner - label_w) / 2)
  local right = inner - label_w - left
  return BORDER_TL .. BORDER_H:rep(left) .. label .. BORDER_H:rep(right) .. BORDER_TR
end

local function bottom_border(width)
  return BORDER_BL .. BORDER_H:rep(math.max(width - 2, 0)) .. BORDER_BR
end

-- ── Text helpers ──────────────────────────────────────────────────────────

function M.line_text(filter)
  return INPUT_PREFIX .. (filter or "")
end

function M.header_lines(filter)
  local w = win_width()
  return {
    top_border(w, TITLE),
    M.line_text(filter),
    bottom_border(w),
  }
end

function M.strip_prefix(raw)
  if raw:sub(1, INPUT_PREFIX_BYTES) == INPUT_PREFIX then
    return raw:sub(INPUT_PREFIX_BYTES + 1)
  end
  return raw
end

-- ── Highlight state resolver ──────────────────────────────────────────────

local function border_hl(is_active, has_filter)
  if is_active then
    return "ExplorerSearchBorderActive"
  end
  if has_filter then
    return "ExplorerSearchBorderFilter"
  end
  return "ExplorerSearchBorder"
end

-- ── Right-side count + closing │ ─────────────────────────────────────────

local function right_chunks(is_active, has_filter, total, cursor)
  local b_hl = border_hl(is_active, has_filter)
  local show_count = cfg.get().search_count and has_filter
  if not show_count then
    return { { " " .. BORDER_V, b_hl } }
  end
  local label, c_hl
  if is_active then
    c_hl = "ExplorerSearchCountActive"
    if total == 0 then
      label = "  no results "
    else
      local cur = cursor or 0
      label = cur > 0 and ("  " .. cur .. "/" .. total .. " ") or ("  " .. total .. " ")
    end
  else
    c_hl = "ExplorerSearchCount"
    label = total == 0 and "  no results " or ("  " .. total .. (total == 1 and " match " or " matches "))
  end
  return {
    { label, c_hl },
    { BORDER_V, b_hl },
  }
end

-- ── Search window (separate split above the tree) ─────────────────────────

local function has_search_win()
  return S.search_win and api.nvim_win_is_valid(S.search_win)
end

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

local function apply_search_win_opts()
  if not has_search_win() then
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
  wo.winfixheight = true
  pcall(function()
    wo.foldcolumn = "0"
  end)
  pcall(function()
    wo.statuscolumn = ""
  end)
  wo.winhl = "Normal:ExplorerSearchNormal,WinBar:ExplorerSearchNormal,WinBarNC:ExplorerSearchNormal"
end

local function ensure_win(buf)
  if has_search_win() then
    api.nvim_win_set_buf(S.search_win, buf)
    apply_search_win_opts()
    return S.search_win
  end

  local prev = api.nvim_get_current_win()
  if S.win and api.nvim_win_is_valid(S.win) then
    pcall(api.nvim_set_current_win, S.win) -- go to tree window
  end
  -- create search split of 3 lines *above* the tree
  vim.cmd("noautocmd keepalt leftabove " .. M.SEARCH_WIN_HEIGHT .. "split")
  S.search_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(S.search_win, buf)
  pcall(api.nvim_win_set_height, S.search_win, M.SEARCH_WIN_HEIGHT)
  apply_search_win_opts()

  -- restore previous window (the original editor, not the tree)
  if S.win and api.nvim_win_is_valid(S.win) then
    pcall(api.nvim_set_current_win, S.win)
  end
  if prev and api.nvim_win_is_valid(prev) and prev ~= S.search_win then
    pcall(api.nvim_set_current_win, prev)
  end

  return S.search_win
end

function M.ensure_window()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil, nil
  end
  local buf = ensure_buf()
  local w = ensure_win(buf)
  return w, buf
end

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

-- ── Layout maths ─────────────────────────────────────────────────────────

local function text_area_info(width, count_display_w)
  local area_w = math.max(width - INPUT_PREFIX_DISPLAY_W - count_display_w, 0)
  return INPUT_PREFIX_BYTES, area_w
end

-- ── Per-region paint helpers ─────────────────────────────────────────────

local function paint_top_border(buf, lines, b_hl)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = b_hl,
    hl_eol = true,
    priority = 5,
  })
  local top = lines[1] or ""
  local t_pos = top:find(TITLE, 1, true)
  if t_pos then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, t_pos - 1, {
      end_col = t_pos - 1 + #TITLE,
      hl_group = "ExplorerSearchTitle",
      priority = 20,
    })
  end
end

local function paint_input_row(buf, lines, is_active, has_filter, chunks)
  local bg_hl = is_active and "ExplorerSearchBgActive" or "ExplorerSearchBg"
  local icon_hl = is_active and "ExplorerSearchIconActive" or "ExplorerSearchIcon"
  local b_hl = border_hl(is_active, has_filter)
  local width = win_width()
  local input_line = lines[M.INPUT_LNUM] or ""
  local line_bytes = #input_line

  local count_label = ""
  for _, chunk in ipairs(chunks) do
    count_label = count_label .. chunk[1]
  end
  local count_w = fn.strdisplaywidth(count_label)

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = -1,
    hl_group = bg_hl,
    hl_eol = true,
    priority = 5,
  })
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = BORDER_V_BYTES,
    hl_group = b_hl,
    priority = 15,
  })
  local icon_start = BORDER_V_BYTES + 1
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, icon_start, {
    end_col = icon_start + SEARCH_ICON_BYTES,
    hl_group = icon_hl,
    priority = 20,
  })

  local text_byte_start, area_w = text_area_info(width, count_w)

  if input_line == INPUT_PREFIX then
    local ph_w = fn.strdisplaywidth(PLACEHOLDER)
    local pad_left = math.max(math.floor((area_w - ph_w) / 2), 0)
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      virt_text = { { (" "):rep(pad_left) .. PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  elseif has_filter and not is_active and line_bytes > INPUT_PREFIX_BYTES then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, text_byte_start, {
      end_row = M.INPUT_ROW,
      end_col = line_bytes,
      hl_group = "ExplorerSearchActiveText",
      priority = 60,
    })
  end

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    virt_text = chunks,
    virt_text_pos = "right_align",
    priority = 100,
  })
end

local function paint_bottom_border(buf, b_hl)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.BOTTOM_ROW, 0, {
    end_col = -1,
    hl_group = b_hl,
    hl_eol = true,
    priority = 5,
  })
end

-- ── Main paint entry point ────────────────────────────────────────────────

function M.paint()
  local _, buf = M.ensure_window()
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local lines = M.header_lines(S.filter)

  api.nvim_set_option_value("modifiable", true, { buf = buf })
  api.nvim_buf_set_lines(buf, 0, M.SEARCH_WIN_HEIGHT, false, lines)
  if not S.search_active then
    api.nvim_set_option_value("modifiable", false, { buf = buf })
  end

  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local is_active = S.search_active
  local has_filter = S.filter ~= nil and S.filter ~= ""
  local b_hl = border_hl(is_active, has_filter)
  local chunks = right_chunks(is_active, has_filter, #S.items, S._search_cursor)

  paint_top_border(buf, lines, b_hl)
  paint_input_row(buf, lines, is_active, has_filter, chunks)
  paint_bottom_border(buf, b_hl)
end

return M
