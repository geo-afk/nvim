--------------------------------------------------------------------------------
-- custom.terminal_manager/utils.lua
-- Pure helper functions shared across all other modules.
-- Accesses M.config lazily (inside function bodies) to avoid circular deps.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")

local M = {}

--- True when `b` is a valid, loaded buffer.
function M.buf_ok(b)
  return b ~= nil and vim.api.nvim_buf_is_valid(b)
end

--- True when `w` is a valid, open window.
function M.win_ok(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

--- True when the terminal job inside `buf` is still running.
function M.term_alive(buf)
  if not M.buf_ok(buf) then
    return false
  end
  local ok, chan = pcall(vim.api.nvim_get_option_value, "channel", { buf = buf })
  return ok and chan and chan > 0 and vim.fn.jobwait({ chan }, 0)[1] == -1
end

--- Find a terminal by id.  Returns (entry, 1-based index) or (nil, nil).
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

--- True when at least one panel window is valid.
function M.panel_open()
  return M.win_ok(state.ui.sidebar_win) or M.win_ok(state.ui.term_win)
end

--- True when both panel windows are valid (panel is fully built).
function M.panel_complete()
  return M.win_ok(state.ui.sidebar_win) and M.win_ok(state.ui.term_win)
end

--- Panel height in lines, clamped between configured bounds.
function M.panel_height()
  local cfg = require("custom.terminal_manager").config
  local h = math.floor(vim.o.lines * cfg.panel_height)
  h = math.max(h, cfg.min_panel_lines)
  h = math.min(h, math.floor(vim.o.lines * cfg.max_panel_frac))
  h = math.min(h, math.max(0, vim.o.lines - 3)) -- always leave room for editor
  return h
end

--- Resolve the default shell (config.shell or vim.o.shell).
function M.get_shell()
  local cfg = require("custom.terminal_manager").config
  return cfg.shell or vim.o.shell
end

--- Set a window option safely (no-op when the window handle is invalid).
function M.win_opt(win, name, value)
  if not M.win_ok(win) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { win = win })
end

--- Set a buffer option safely (no-op when the buffer handle is invalid).
function M.buf_opt(buf, name, value)
  if not M.buf_ok(buf) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { buf = buf })
end

--- Nil-out all panel handles (called after the panel is closed).
function M.reset_panel_handles()
  state.ui.sidebar_buf = nil
  state.ui.sidebar_win = nil
  state.ui.term_win = nil
end

return M
