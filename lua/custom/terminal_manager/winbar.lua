--------------------------------------------------------------------------------
-- terminal_manager/winbar.lua
-- Manages the status winbar shown above the terminal pane.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

--- Rebuild and apply the winbar string for ui.term_win.
function M.update()
  if not utils.win_ok(state.ui.term_win) then
    return
  end

  local t = utils.find_term(state.active_id)
  if not t then
    utils.win_opt(state.ui.term_win, "winbar", "")
    return
  end

  local profile = t.profile or {}
  local icon = profile.icon or "$"
  local alive = utils.term_alive(t.buf)
  local dot = alive and "●" or "○"
  local dot_hl = alive and "TermManagerWinbarDot" or "TermManagerDead"
  local profname = profile.name or "shell"

  -- Left side : dot + icon + terminal name + profile tag
  -- Right side (after %=): keyboard hints
  local bar = string.format(
    " %%#%s#%s %%#TermManagerWinbar#%s %s%%#TermManagerWinbarHint# [%s]%%*"
      .. "%%=%%#TermManagerWinbarHint# <Esc><Esc> normal  ·  <leader>zT sidebar ",
    dot_hl,
    dot,
    icon,
    t.name,
    profname
  )
  utils.win_opt(state.ui.term_win, "winbar", bar)
end

return M
