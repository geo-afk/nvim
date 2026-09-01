--------------------------------------------------------------------------------
-- custom/workspace_manager/init.lua
-- require("custom.workspace_manager")
--
-- Hide auxiliary UI (terminals, LazyGit, DAP UI, Overseer, floats, splits)
-- without destroying it, then bring the exact same window back later. The
-- underlying buffer/job/process is never touched — only the window.
--
-- LAYOUT
--   [source code]                      [source code]
--   [terminal: npm run dev]   --vs-->  (terminal keeps running, hidden)
--                             <--vr--
--
-- KEYMAPS (global, normal mode)
--   <leader>vs   stash current window     <leader>vt   toggle stash / restore
--   <leader>vr   restore most recent      <leader>vp   stashed-windows picker
--
-- COMMANDS
--   :WorkspaceStash   :WorkspaceRestore    :WorkspaceToggle   :WorkspaceList
--   :WorkspaceRename  :WorkspaceTerminate  :WorkspaceRemove   :WorkspaceClear
--
-- MODULES
--   init.lua        entry point + public Lua API
--   state.lua       MRU registry
--   providers.lua   per-UI-kind adapters (detect/capture/hide/restore)
--   actions.lua     stash/restore/toggle/terminate/remove/rename
--   picker.lua      stashed-windows picker (custom.ui)
--   commands.lua    keymaps + :Workspace* commands
--------------------------------------------------------------------------------
local M = {}

local actions = require("custom.workspace_manager.actions")
local state = require("custom.workspace_manager.state")

M.stash = actions.stash
M.restore = actions.restore
M.toggle = actions.toggle
M.rename = actions.rename
M.remove = actions.remove
M.terminate = actions.terminate
M.clear = actions.clear

function M.pick()
  require("custom.workspace_manager.picker").open()
end

--- Snapshot of stashed items, most-recent first. For the picker, statusline,
--- or anything else that wants to introspect without importing state.lua.
function M.list()
  return state.list()
end

--- Number of currently stashed items — cheap, safe to poll from a statusline
--- component (e.g. `custom.tabline`/`custom.statusline`) without coupling
--- either module to this one.
function M.count()
  return state.count()
end

function M.setup()
  require("custom.workspace_manager.commands").setup()
end

return M
