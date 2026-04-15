--------------------------------------------------------------------------------
-- terminal_manager/state.lua
-- Shared mutable state.  All other modules require this; nothing here
-- requires any sibling module (avoids circular dependencies).
--------------------------------------------------------------------------------

local M = {}

-- List of terminal entries.
-- Each entry: { id:int, name:string, buf:int|nil, profile:table }
M.terminals = {}

-- Monotonically increasing terminal ID counter.
M.next_id = 1

-- ID of the terminal currently shown in ui.term_win.
M.active_id = nil

-- Window / buffer handles for the panel.
M.ui = {
  sidebar_buf = nil,
  sidebar_win = nil,
  term_win = nil,
}

-- Populated by sidebar.render(); consumed by sidebar action handlers.
-- term_rows : { [1-based row] = index into M.terminals }
M.sidebar_meta = { term_rows = {}, new_row = nil, help_row = nil }

-- Extmark namespace shared by sidebar highlights.
M.ns = vim.api.nvim_create_namespace("TermManager")

-- Handle for the help floating window (nil when closed).
M.help_win_h = nil

return M
