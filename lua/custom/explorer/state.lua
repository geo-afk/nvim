-- explorer/state.lua
-- Shared mutable state. Every module imports this table and reads/writes it.
-- Nothing in here has behaviour — just data.

local api = vim.api

local S = {
  -- Window / buffer
  buf = nil, -- explorer buffer
  win = nil, -- explorer window
  root = nil, -- current root path (absolute, no trailing slash)
  prev_win = nil, -- window to return to when opening files

  -- Tree
  items = {}, -- flat list; index == 1-based line number in buffer
  open_dirs = {}, -- set<path> → true  (expanded directories)

  -- Git
  git = {}, -- path → status char  (M/A/D/R/U/?)

  -- Search / filter
  filter = nil, -- nil = inactive, string = active filter pattern
  filter_win = nil, -- floating input window handle
  filter_buf = nil, -- floating input buffer handle

  -- Multi-select marks
  marks = {}, -- set<path> → true

  -- Highlight namespaces
  ns = api.nvim_create_namespace 'explorer_tree', -- icons, connectors, names
  git_ns = api.nvim_create_namespace 'explorer_git', -- git signs + name colours
  mark_ns = api.nvim_create_namespace 'explorer_marks', -- mark badges

  -- Icon provider function resolved once on open()
  icon_fn = nil,

  -- Build token: incremented on every render() call; stale async builds check it
  build_tok = 0,

  -- Injected by init.lua so win.lua can call close without a hard require("explorer")
  close_fn = nil,
}

return S
