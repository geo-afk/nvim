--------------------------------------------------------------------------------
-- custom.terminal_manager/terminal.lua
-- Spawning terminal jobs and switching the visible terminal in the pane.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local profiles = require("custom.terminal_manager.profiles")

local M = {}

-- ── Internal ──────────────────────────────────────────────────────────────────

--- Launch a shell inside ui.term_win.
--- t.buf must already be set as the window's buffer before this is called.
local function spawn_in_term_win(t)
  if not utils.win_ok(state.ui.term_win) then
    return
  end

  local profile = t.profile or {}
  local cmd = profiles.profile_cmd(profile)
  local env = profiles.profile_env(profile)
  local cwd = profile.cwd or vim.fn.getcwd()

  vim.api.nvim_win_call(state.ui.term_win, function()
    -- termopen() converts the current buffer into a terminal buffer in-place.
    vim.fn.termopen(cmd, {
      env = env,
      cwd = cwd,
      on_exit = function()
        vim.schedule(function()
          -- Refresh alive/dead indicators when the shell exits.
          require("custom.terminal_manager.sidebar").render()
          require("custom.terminal_manager.winbar").update()
        end)
      end,
    })
  end)
end

-- ── Public ────────────────────────────────────────────────────────────────────

--- Make terminal `t` the visible one in ui.term_win.
--- Rebuilds the panel if it has been closed.
--- Auto-restarts the shell when it has exited.
function M.show(t)
  if not t then
    return
  end

  -- Ensure the panel is open (rebuilds it if closed).
  if not require("custom.terminal_manager.panel").ensure() then
    return
  end

  state.active_id = t.id

  -- Lazily create the underlying buffer on first use.
  if not utils.buf_ok(t.buf) then
    t.buf = vim.api.nvim_create_buf(false, false)
    -- "hide" prevents Neovim from unloading the buffer when we switch away.
    utils.buf_opt(t.buf, "bufhidden", "hide")
  end

  vim.api.nvim_win_set_buf(state.ui.term_win, t.buf)

  -- Spawn the shell only when it is not already running.
  if not utils.term_alive(t.buf) then
    spawn_in_term_win(t)
  end

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update()

  -- Switch focus into the terminal and enter insert mode.
  if utils.win_ok(state.ui.term_win) then
    vim.api.nvim_set_current_win(state.ui.term_win)
    vim.cmd("startinsert")
  end
end

--- Kill the existing shell (if any) and start a fresh one in the same slot.
function M.restart(t)
  if utils.buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  t.buf = nil
  M.show(t)
end

return M
