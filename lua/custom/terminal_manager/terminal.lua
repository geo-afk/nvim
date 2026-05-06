--------------------------------------------------------------------------------
-- custom/terminal_manager/terminal.lua
-- Spawn and display terminals; attach links + venv detection.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local profiles = require("custom.terminal_manager.profiles")
local env_file = require("custom.terminal_manager.env")

local M = {}

local function resolve_cwd(profile)
  local cwd = (profile or {}).cwd
  if not cwd or cwd == "" then
    return vim.fn.getcwd()
  end
  if cwd == "git_dir" then
    local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
    if root and root ~= "" and not root:match("^fatal") then
      return root
    end
    return vim.fn.getcwd()
  end
  return vim.fn.expand(cwd)
end

local function spawn_in_win(t, win)
  if not utils.win_ok(win) then
    return
  end

  local profile = t.profile or {}
  local cmd = profiles.profile_cmd(profile)
  local env = profiles.profile_env(profile)
  local cwd = resolve_cwd(profile)
  env = env_file.apply(env, vim.loop.cwd())

  -- Detect venv and inject its env.
  local venv = require("custom.terminal_manager.venv").detect(cwd)
  t.venv = venv
  if venv and venv.env then
    env = vim.tbl_extend("force", env, venv.env)
  end

  vim.api.nvim_win_call(win, function()
    vim.fn.termopen(cmd, {
      env = env,
      cwd = cwd,
      on_exit = function()
        vim.schedule(function()
          if profile.close_on_exit then
            require("custom.terminal_manager").delete_term(t.id)
          else
            require("custom.terminal_manager.sidebar").render()
            require("custom.terminal_manager.winbar").update_all()
          end
        end)
      end,
    })
  end)

  -- Attach link detection to the new buffer.
  vim.schedule(function()
    require("custom.terminal_manager.links").attach(t.buf)
  end)

  if profile.startup_command and profile.startup_command ~= "" then
    vim.defer_fn(function()
      if utils.term_alive(t.buf) then
        local ok, chan = pcall(vim.api.nvim_get_option_value, "channel", { buf = t.buf })
        if ok and chan and chan > 0 then
          vim.fn.chansend(chan, profile.startup_command .. "\n")
        end
      end
    end, 120)
  end
end

local function ensure_buf(t)
  if not utils.buf_ok(t.buf) then
    t.buf = require("custom.ui.buffer").create_raw(false, false)
    utils.buf_opt(t.buf, "bufhidden", "hide")
  end
end

function M.show_in_win(t, win)
  if not t or not utils.win_ok(win) then
    return
  end

  ensure_buf(t)
  vim.api.nvim_win_set_buf(win, t.buf)
  if not utils.term_alive(t.buf) then
    spawn_in_win(t, win)
  end

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update_all()
end

-- ── Public ────────────────────────────────────────────────────────────────────

--- Show terminal `t` in the primary pane, rebuilding the panel if needed.
---@param t table terminal entry
---@param mode "float"|"panel"|nil optional mode override
function M.show(t, mode)
  if not t then
    return false
  end

  local target_mode = mode or state.display_mode
  if target_mode == "float" then
    return require("custom.terminal_manager.float").open(t)
  end

  if not require("custom.terminal_manager.panel").ensure() then
    return false
  end

  state.active_id = t.id
  M.show_in_win(t, state.ui.term_win)

  if utils.win_ok(state.ui.term_win) then
    vim.api.nvim_set_current_win(state.ui.term_win)
    vim.cmd("startinsert")
  end
  return true
end

--- Kill the shell and restart in the same slot.
function M.restart(t)
  if utils.buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  t.buf = nil
  t.venv = nil
  M.show(t)
end

return M
