--------------------------------------------------------------------------------
-- custom/terminal_manager/utils.lua
--------------------------------------------------------------------------------
local state = require("custom.terminal_manager.state")
local M = {}

function M.buf_ok(b)
  return b ~= nil and vim.api.nvim_buf_is_valid(b)
end
function M.win_ok(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

function M.term_alive(buf)
  if not M.buf_ok(buf) then
    return false
  end
  local ok, chan = pcall(vim.api.nvim_get_option_value, "channel", { buf = buf })
  return ok and chan and chan > 0 and vim.fn.jobwait({ chan }, 0)[1] == -1
end

function M.find_term(id)
  if not id then
    return nil, nil
  end
  for i, t in ipairs(state.terminals) do
    if t.id == id then
      return t, i
    end
  end
  return nil, nil
end

function M.panel_open()
  return M.win_ok(state.ui.sidebar_win) or M.win_ok(state.ui.term_win)
end

function M.panel_complete()
  return M.win_ok(state.ui.sidebar_win) and M.win_ok(state.ui.term_win)
end

function M.float_open()
  return M.win_ok(state.ui.float_win)
end

function M.panel_height()
  local cfg = require("custom.terminal_manager").config
  local h = math.floor(vim.o.lines * cfg.panel_height)
  h = math.max(h, cfg.min_panel_lines)
  h = math.min(h, math.floor(vim.o.lines * cfg.max_panel_frac))
  h = math.min(h, math.max(0, vim.o.lines - 3))
  return h
end

function M.get_shell()
  local cfg = require("custom.terminal_manager").config
  return cfg.shell or vim.o.shell
end

function M.win_opt(win, name, value)
  if not M.win_ok(win) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { win = win })
end

function M.buf_opt(buf, name, value)
  if not M.buf_ok(buf) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { buf = buf })
end

function M.reset_panel_handles()
  state.ui.sidebar_buf = nil
  state.ui.sidebar_win = nil
  state.ui.term_win = nil
  state.ui.term_win2 = nil
  state.split_mode = false
end

function M.reset_float_handles()
  state.ui.float_win = nil
  state.float_id = nil
end

--- Return which panel pane (1=primary, 2=secondary) is currently focused,
--- or nil if neither is focused.
function M.focused_pane()
  local cur = vim.api.nvim_get_current_win()
  if cur == state.ui.term_win then
    return 1
  end
  if cur == state.ui.term_win2 then
    return 2
  end
  if cur == state.ui.float_win then
    return 1
  end
  return nil
end

--- Return the active_id for the given pane (1 or 2).
function M.pane_active_id(pane)
  if pane == 2 then
    return state.active_id2
  end
  return state.active_id
end

--- Set the active_id for the given pane.
function M.set_pane_active_id(pane, id)
  if pane == 2 then
    state.active_id2 = id
  else
    state.active_id = id
  end
end

return M
