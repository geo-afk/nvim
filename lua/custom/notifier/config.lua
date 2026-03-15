-- notify-manager/config.lua
-- Default configuration for the notification manager

local M = {}

M.defaults = {
  -- Default timeout in milliseconds (0 = no auto-dismiss)
  timeout = 4000,

  -- Maximum number of notifications visible at once
  max_visible = 5,

  -- Maximum number of entries in history
  max_history = 100,

  -- Where to display notifications
  -- "top_right" | "top_left" | "bottom_right" | "bottom_left" | "top_center" | "bottom_center"
  position = 'top_right',

  -- Minimum width for notification windows
  min_width = 30,

  -- Maximum width for notification windows (0 = auto / no limit)
  max_width = 60,

  -- Border style: "none" | "single" | "double" | "rounded" | "solid" | "shadow"
  border = 'rounded',

  -- Window transparency (0–100)
  winblend = 0,

  -- Whether to animate slide-in / fade-out
  animate = true,

  -- Animation fps
  fps = 30,

  -- Padding inside the notification window: { top, right, bottom, left }
  padding = { top = 0, right = 1, bottom = 0, left = 1 },

  -- Vertical gap between stacked notifications (rows)
  gap = 1,

  -- Icons per log level (requires a Nerd Font)
  icons = {
    ERROR = ' ',
    WARN = ' ',
    INFO = ' ',
    DEBUG = ' ',
    TRACE = '󰓤 ',
  },

  -- Highlight groups per log level
  highlights = {
    ERROR = 'NotifyError',
    WARN = 'NotifyWarn',
    INFO = 'NotifyInfo',
    DEBUG = 'NotifyDebug',
    TRACE = 'NotifyTrace',
    title = 'NotifyTitle',
    border = 'NotifyBorder',
    body = 'NotifyBody',
  },

  -- Whether to replace vim.notify globally on setup
  replace_vim_notify = true,

  -- Whether to show LSP progress notifications
  lsp_progress = true,

  -- Suppress notifications when in insert mode
  suppress_in_insert = false,

  -- Callback fired when a notification is shown: function(notif)
  on_open = nil,

  -- Callback fired when a notification is closed: function(notif)
  on_close = nil,
}

--- Merge user opts into defaults (shallow for top-level tables)
---@param opts table|nil
---@return table
function M.build(opts)
  opts = opts or {}
  local cfg = vim.deepcopy(M.defaults)
  for k, v in pairs(opts) do
    if type(v) == 'table' and type(cfg[k]) == 'table' then
      cfg[k] = vim.tbl_extend('force', cfg[k], v)
    else
      cfg[k] = v
    end
  end
  return cfg
end

return M
