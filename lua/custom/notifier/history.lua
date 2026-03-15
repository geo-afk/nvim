-- notify-manager/highlights.lua
-- Define and link highlight groups

local M = {}

--- Set up default highlight groups linked to built-in groups.
--- Users can override these in their colorscheme / after/ftplugin.
function M.setup()
  local hl = vim.api.nvim_set_hl

  -- Level accents (foreground only; let the bg come from Normal float)
  hl(0, 'NotifyError', { default = true, fg = '#f38ba8', bold = true })
  hl(0, 'NotifyWarn', { default = true, fg = '#fab387', bold = true })
  hl(0, 'NotifyInfo', { default = true, fg = '#89b4fa', bold = true })
  hl(0, 'NotifyDebug', { default = true, fg = '#a6e3a1' })
  hl(0, 'NotifyTrace', { default = true, fg = '#cba6f7' })

  -- Structural highlights
  hl(0, 'NotifyTitle', { default = true, fg = '#cdd6f4', bold = true })
  hl(0, 'NotifyBody', { default = true, link = 'Normal' })
  hl(0, 'NotifyBorder', { default = true, fg = '#45475a' })

  -- Icon backgrounds (used as winhighlight overrides)
  hl(0, 'NotifyErrorBg', { default = true, bg = '#3d1a1a' })
  hl(0, 'NotifyWarnBg', { default = true, bg = '#3d2c1a' })
  hl(0, 'NotifyInfoBg', { default = true, bg = '#1a2a3d' })
  hl(0, 'NotifyDebugBg', { default = true, bg = '#1a3d1a' })
  hl(0, 'NotifyTraceBg', { default = true, bg = '#2d1a3d' })

  -- History buffer
  hl(0, 'NotifyHistoryTitle', { default = true, link = 'Title' })
  hl(0, 'NotifyHistorySep', { default = true, link = 'Comment' })
end

--- Return the highlight group name for a given log level string.
---@param level string  e.g. "ERROR", "WARN", "INFO" …
---@return string
function M.level_hl(level)
  local map = {
    ERROR = 'NotifyError',
    WARN = 'NotifyWarn',
    INFO = 'NotifyInfo',
    DEBUG = 'NotifyDebug',
    TRACE = 'NotifyTrace',
  }
  return map[level] or 'NotifyInfo'
end

return M
