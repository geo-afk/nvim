-- custom/explorer/state.lua

local api = vim.api

local S = {
  buf = nil,
  win = nil,
  root = nil,
  prev_win = nil,

  -- true while the user is typing in the search bar (line 1, insert mode)
  search_active = false,

  -- S.items[i] lives at buffer line i+1 (1-based), row i (0-based)
  items = {},
  open_dirs = {},

  git = {},
  filter = nil,
  marks = {},
  recent_roots = {},

  ns = api.nvim_create_namespace 'explorer_tree',
  git_ns = api.nvim_create_namespace 'explorer_git',
  mark_ns = api.nvim_create_namespace 'explorer_marks',
  hdr_ns = api.nvim_create_namespace 'explorer_header',

  icon_fn = nil,
  build_tok = 0,
  close_fn = nil,

  -- Path to move the cursor to after the next build completes.
  -- Set by M.reveal(); consumed and cleared by render._reveal_cursor().
  -- This lets reveal() and render.render() share a single build pass
  -- instead of each starting their own competing tree traversal.
  _reveal_target = nil,
}

return S
