--------------------------------------------------------------------------------
-- custom/terminal_manager/state.lua
--------------------------------------------------------------------------------
local M = {}

M.terminals = {}
M.next_id = 1
M.active_id = nil
M.active_id2 = nil -- terminal in secondary split pane

M.ui = {
  sidebar_buf = nil,
  sidebar_win = nil,
  term_win = nil, -- primary terminal pane
  term_win2 = nil, -- secondary terminal pane (split mode only)
  float_win = nil, -- floating terminal window
}

M.split_mode = false
M.panel_hidden = false -- set by hide(); cleared by show()
M.display_mode = "panel" -- "panel" | "float"
M.float_id = nil

M.sidebar_meta = {
  term_rows = {},
  new_row = nil,
  profiles_row = nil,
  help_row = nil,
}

M.help_win_h = nil

M.ns = vim.api.nvim_create_namespace("TermManager")
M.link_ns = vim.api.nvim_create_namespace("TermManagerLinks")

M.venv_cache = {} -- { [dir_path] = venv_info table | false }

return M
