--------------------------------------------------------------------------------
-- custom/terminal_manager/split.lua
-- Manage a second terminal pane inside the terminal area.
--
-- Layout (split mode):
--   [sidebar_win | term_win | term_win2]
--
-- Public API:
--   split.open()         split the terminal area in two
--   split.close()        collapse back to one pane
--   split.toggle()       open if closed, close if open
--   split.focus(pane)    focus pane 1 or 2
--   split.swap()         exchange the two terminals
--   split.move_to(pane)  move current terminal to the given pane
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local env_file = require("custom.terminal_manager.env")

local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function show_in_win(win, t)
  if not t or not utils.win_ok(win) then
    return
  end

  if not utils.buf_ok(t.buf) then
    t.buf = require("custom.ui.buffer").create_raw(false, false)
    utils.buf_opt(t.buf, "bufhidden", "hide")
  end

  vim.api.nvim_win_set_buf(win, t.buf)

  if not utils.term_alive(t.buf) then
    -- Spawn shell in that window
    local profiles = require("custom.terminal_manager.profiles")
    local profile = t.profile or {}
    local cmd = profiles.profile_cmd(profile)
    local env = profiles.profile_env(profile)
    env = env_file.apply(env, vim.uv.cwd())
    -- Apply venv env if present
    if t.venv and t.venv.env then
      env = vim.tbl_extend("force", env, t.venv.env)
    end
    local cwd = (profile.cwd and profile.cwd ~= "") and vim.fn.expand(profile.cwd) or vim.fn.getcwd()

    vim.api.nvim_win_call(win, function()
      vim.fn.jobstart(cmd, {
        term = true,
        env = env,
        cwd = cwd,
        on_exit = function()
          vim.schedule(function()
            require("custom.terminal_manager.sidebar").render()
            require("custom.terminal_manager.winbar").update_all()
          end)
        end,
      })
    end)
  end
end

local function apply_win_opts(win)
  utils.win_opt(win, "number", false)
  utils.win_opt(win, "relativenumber", false)
  utils.win_opt(win, "signcolumn", "no")
end

-- ── Public ────────────────────────────────────────────────────────────────────

--- Open a second terminal pane by splitting term_win vertically.
--- If `t` is provided, show it in the new pane; otherwise pick the next
--- available terminal (or the same one if only one exists).
---@param t table|nil   terminal entry to show in pane 2
function M.open(t)
  if state.display_mode == "float" then
    vim.notify("TermManager: split panes are only available in panel mode", vim.log.levels.INFO)
    return
  end
  if not utils.win_ok(state.ui.term_win) then
    vim.notify("TermManager: open the panel first (<leader>zt)", vim.log.levels.WARN)
    return
  end
  if state.split_mode then
    vim.notify("TermManager: already in split mode", vim.log.levels.INFO)
    return
  end

  -- Choose a terminal for the second pane.
  local t2 = t
  if not t2 then
    -- Try the next terminal after active_id
    local current_t, idx = require("custom.terminal_manager.utils").find_term(state.active_id)
    if idx and state.terminals[idx + 1] then
      t2 = state.terminals[idx + 1]
    elseif state.terminals[1] then
      t2 = state.terminals[1]
    end
  end

  -- Split term_win vertically
  vim.api.nvim_set_current_win(state.ui.term_win)
  vim.cmd("vsplit")
  state.ui.term_win2 = vim.api.nvim_get_current_win()
  apply_win_opts(state.ui.term_win2)

  state.split_mode = true
  state.active_id2 = t2 and t2.id or state.active_id

  if t2 then
    show_in_win(state.ui.term_win2, t2)
  end

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update_all()

  -- Focus the new pane
  if utils.win_ok(state.ui.term_win2) then
    vim.api.nvim_set_current_win(state.ui.term_win2)
    vim.cmd("startinsert")
  end
end

--- Collapse back to a single terminal pane.
function M.close()
  if not state.split_mode then
    return
  end

  if utils.win_ok(state.ui.term_win2) then
    pcall(vim.api.nvim_win_close, state.ui.term_win2, true)
  end
  state.ui.term_win2 = nil
  state.active_id2 = nil
  state.split_mode = false

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update_all()

  if utils.win_ok(state.ui.term_win) then
    vim.api.nvim_set_current_win(state.ui.term_win)
    vim.cmd("startinsert")
  end
end

--- Toggle the split.
function M.toggle()
  if state.split_mode then
    M.close()
  else
    M.open()
  end
end

--- Focus pane 1 (primary) or 2 (secondary).
---@param pane integer  1 or 2
function M.focus(pane)
  local win = pane == 2 and state.ui.term_win2 or state.ui.term_win
  if utils.win_ok(win) then
    vim.api.nvim_set_current_win(win)
    vim.cmd("startinsert")
  end
end

--- Swap the terminals shown in pane 1 and pane 2.
function M.swap()
  if not state.split_mode then
    return
  end

  local id1, id2 = state.active_id, state.active_id2
  local t1 = utils.find_term(id1)
  local t2 = utils.find_term(id2)

  state.active_id = id2
  state.active_id2 = id1

  if t2 and utils.win_ok(state.ui.term_win) then
    show_in_win(state.ui.term_win, t2)
  end
  if t1 and utils.win_ok(state.ui.term_win2) then
    show_in_win(state.ui.term_win2, t1)
  end

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update_all()
end

--- Show terminal `t` in a specific pane (1 or 2).
---@param t    table   terminal entry
---@param pane integer 1 or 2
function M.show_in_pane(t, pane)
  if not t then
    return
  end

  if pane == 2 then
    if not state.split_mode then
      M.open(t)
      return
    end
    state.active_id2 = t.id
    show_in_win(state.ui.term_win2, t)
  else
    state.active_id = t.id
    show_in_win(state.ui.term_win, t)
  end

  require("custom.terminal_manager.sidebar").render()
  require("custom.terminal_manager.winbar").update_all()
end

return M
