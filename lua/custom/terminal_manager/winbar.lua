--------------------------------------------------------------------------------
-- custom/terminal_manager/winbar.lua
-- Winbar for primary and secondary terminal panes.
-- Shows: status dot, icon, name, profile, venv, keyboard hints.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

local function bar_for(t, hints)
  if not t then
    return ""
  end
  local profile = t.profile or {}
  local icon = profile.icon or "$"
  local alive = utils.term_alive(t.buf)
  local dot = alive and "●" or "○"
  local dot_hl = alive and "TermManagerWinbarDot" or "TermManagerDead"
  local profname = profile.name or "shell"

  -- Venv indicator
  local venv_str = ""
  if t.venv and t.venv.display then
    venv_str = string.format(" %%#TermManagerWinbarHint# %s%%*", t.venv.display)
  end

  -- Split mode indicator
  local split_str = state.split_mode and " %%#TermManagerWinbarHint#[split]%%*" or ""

  return string.format(
    " %%#%s#%s %%#TermManagerWinbar#%s %s%%#TermManagerWinbarHint# [%s]%%*%s%s" .. "%%=%%#TermManagerWinbarHint# %s ",
    dot_hl,
    dot,
    icon,
    t.name,
    profname,
    venv_str,
    split_str,
    hints
  )
end

local PRIMARY_HINTS = "<Esc><Esc> normal  ·  <C-f> search  ·  <leader>zT sidebar"
local SECONDARY_HINTS = "<Esc><Esc> normal  ·  <C-f> search  ·  <leader>z| split"

function M.update_all()
  -- Primary pane
  if utils.win_ok(state.ui.term_win) then
    local t = utils.find_term(state.active_id)
    utils.win_opt(state.ui.term_win, "winbar", bar_for(t, PRIMARY_HINTS))
  end
  -- Secondary pane
  if state.split_mode and utils.win_ok(state.ui.term_win2) then
    local t2 = utils.find_term(state.active_id2)
    utils.win_opt(state.ui.term_win2, "winbar", bar_for(t2, SECONDARY_HINTS))
  end
end

-- Keep backward-compat alias used by older callsites
M.update = M.update_all

return M
