local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")

local api = vim.api
local fn = vim.fn

local M = {}

local SEARCH_ICON = "󰍉"
local INPUT_PREFIX = "│ " .. SEARCH_ICON .. " "
local PLACEHOLDER = "Filter files"
local TITLE = " Search "

M.INPUT_PREFIX = INPUT_PREFIX
M.HEADER_LINES = 3
M.INPUT_ROW = 1
M.INPUT_LNUM = 2
M.ITEM_ROW_OFFSET = 3

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
  return { "", "", "" }
end

function M.lock_tree_view()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  api.nvim_win_call(S.win, function()
    local view = fn.winsaveview()
    local line_count = S.buf and api.nvim_buf_is_valid(S.buf) and api.nvim_buf_line_count(S.buf) or M.HEADER_LINES
    local min_top = math.min(M.HEADER_LINES + 1, math.max(line_count, 1))
    if view.topline < min_top then
      view.topline = min_top
    end
    fn.winrestview(view)
  end)
  local line = api.nvim_win_get_cursor(S.win)[1]
  if line <= M.HEADER_LINES and #S.items > 0 then
    pcall(api.nvim_win_set_cursor, S.win, { M.HEADER_LINES + 1, 0 })
  end
end

local function win_width()
  local width = 0
  if S.win and api.nvim_win_is_valid(S.win) then
    width = api.nvim_win_get_width(S.win)
  end
  return math.max(width, 8)
end

local function border_text(width, title)
  local inner = math.max(width - 2, 0)
  local label = title or ""
  local label_w = math.min(fn.strdisplaywidth(label), inner)
  if label_w == 0 then
    return "╭" .. ("─"):rep(inner) .. "╮"
  end

  local left = math.floor((inner - label_w) / 2)
  local right = inner - label_w - left
  return "╭" .. ("─"):rep(left) .. label .. ("─"):rep(right) .. "╮"
end

local function bottom_border(width)
  return "╰" .. ("─"):rep(math.max(width - 2, 0)) .. "╯"
end

function M.line_text(filter)
  return INPUT_PREFIX .. (filter or "")
end

function M.header_lines(filter)
  local width = win_width()
  return {
    border_text(width, TITLE),
    M.line_text(filter),
    bottom_border(width),
  }
end

function M.strip_prefix(raw)
  if raw:sub(1, #INPUT_PREFIX) == INPUT_PREFIX then
    return raw:sub(#INPUT_PREFIX + 1)
  end
  return raw
end

function M.ensure_window()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil
  end
  return S.win
end

function M.close()
  S.search_win = nil
  S.search_buf = nil
end

local function right_chunks()
  local show_count = cfg.get().search_count and S.filter and S.filter ~= ""
  local total = #S.items
  local border_hl
  if S.search_active then
    border_hl = "ExplorerSearchBorderActive"
  elseif show_count then
    border_hl = "ExplorerSearchBorderFilter"
  else
    border_hl = "ExplorerSearchBorder"
  end

  if not show_count then
    return {
      { " │", border_hl },
    }
  end

  local label
  local count_hl
  if S.search_active then
    count_hl = "ExplorerSearchCountActive"
    if total == 0 then
      label = " 0 results "
    else
      local cur = S._search_cursor or 0
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

function M.paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines = M.header_lines(S.filter)
  api.nvim_set_option_value("modifiable", true, { buf = buf })
  api.nvim_buf_set_lines(buf, 0, M.HEADER_LINES, false, lines)
  if not S.search_active then
    api.nvim_set_option_value("modifiable", false, { buf = buf })
  end
  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local is_active = S.search_active
  local has_filter = S.filter and S.filter ~= ""
  local input_line = lines[M.INPUT_LNUM] or ""
  local bg_hl = is_active and "ExplorerSearchBgActive" or "ExplorerSearchBg"
  local icon_hl = is_active and "ExplorerSearchIconActive" or "ExplorerSearchIcon"
  local border_hl
  if is_active then
    border_hl = "ExplorerSearchBorderActive"
  elseif has_filter then
    border_hl = "ExplorerSearchBorderFilter"
  else
    border_hl = "ExplorerSearchBorder"
  end

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 2, {
    end_col = 2 + #TITLE,
    hl_group = "ExplorerSearchTitle",
    priority = 20,
  })

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = -1,
    hl_group = bg_hl,
    hl_eol = true,
    priority = 5,
  })
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    end_col = 1,
    hl_group = border_hl,
    priority = 20,
  })
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 2, {
    end_col = 2 + #SEARCH_ICON,
    hl_group = icon_hl,
    priority = 20,
  })

  if input_line == INPUT_PREFIX then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, #INPUT_PREFIX, {
      virt_text = { { PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  elseif has_filter and not is_active and #input_line > #INPUT_PREFIX then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, #INPUT_PREFIX, {
      end_row = M.INPUT_ROW,
      end_col = #input_line,
      hl_group = "ExplorerSearchActiveText",
      priority = 60,
    })
  end

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, M.INPUT_ROW, 0, {
    virt_text = right_chunks(),
    virt_text_pos = "right_align",
    priority = 100,
  })

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 2, 0, {
    end_col = -1,
    hl_group = border_hl,
    hl_eol = true,
    priority = 5,
  })

  M.lock_tree_view()
end

return M
