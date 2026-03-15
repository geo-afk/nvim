-- notify-manager/history.lua
-- Stores a ring-buffer of past notifications and provides a viewer.

local M = {}

local _history = {} ---@type table[]
local _max = 100

---@param max integer
function M.set_max(max)
  _max = max
end

--- Push a notification record into history.
---@param notif table
function M.push(notif)
  table.insert(_history, 1, {
    id = notif.id,
    message = notif.message,
    level = notif.level,
    title = notif.title,
    timestamp = os.time(),
    time_str = os.date '%H:%M:%S',
  })
  if #_history > _max then
    table.remove(_history)
  end
end

--- Return a copy of the history list (newest first).
---@return table[]
function M.get()
  return vim.deepcopy(_history)
end

--- Clear all history.
function M.clear()
  _history = {}
end

--- Open a floating window showing the notification history.
function M.show()
  local items = _history
  if #items == 0 then
    vim.notify('[notify-manager] No notification history yet.', vim.log.levels.INFO)
    return
  end

  -- Build buffer lines
  local lines = {}
  local hl_map = {} -- { line, col_start, col_end, hl_group }

  table.insert(lines, '  Notification History (' .. #items .. ' entries)')
  table.insert(lines, string.rep('─', 60))

  local icons = {
    ERROR = ' ',
    WARN = ' ',
    INFO = ' ',
    DEBUG = ' ',
    TRACE = '󰓤 ',
  }
  local hl_groups = {
    ERROR = 'NotifyError',
    WARN = 'NotifyWarn',
    INFO = 'NotifyInfo',
    DEBUG = 'NotifyDebug',
    TRACE = 'NotifyTrace',
  }

  for i, n in ipairs(items) do
    local icon = icons[n.level] or ' '
    local hl = hl_groups[n.level] or 'NotifyInfo'
    local title = n.title and ('[' .. n.title .. '] ') or ''
    local line = string.format(' %s %s %s%s', n.time_str, icon, title, n.message)

    -- Track highlighting positions
    local icon_start = #(' ' .. n.time_str .. ' ')
    table.insert(hl_map, { #lines, icon_start, icon_start + #icon - 1, hl })

    -- Multi-line messages: indent continuation lines
    local msg_lines = vim.split(line, '\n', { plain = true })
    for j, ml in ipairs(msg_lines) do
      if j == 1 then
        table.insert(lines, ml)
      else
        table.insert(lines, '          ' .. ml)
      end
    end

    if i < #items then
      table.insert(lines, '')
    end
  end

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'notify-history')

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace 'notify_history'
  -- Title
  vim.api.nvim_buf_add_highlight(buf, ns, 'NotifyHistoryTitle', 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, 'NotifyHistorySep', 1, 0, -1)
  -- Level icons
  for _, h in ipairs(hl_map) do
    vim.api.nvim_buf_add_highlight(buf, ns, h[4], h[1], h[2], h[3])
  end

  -- Window dimensions
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' 󰂙 Notification History ',
    title_pos = 'center',
  })

  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:NotifyBorder,FloatTitle:NotifyHistoryTitle')
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  vim.api.nvim_win_set_option(win, 'wrap', false)

  -- Close keymaps
  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, key in ipairs { 'q', '<Esc>', '<CR>' } do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', { noremap = true, silent = true, callback = close })
  end
end

return M
