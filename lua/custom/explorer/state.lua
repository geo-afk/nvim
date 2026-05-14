-- custom/explorer/state.lua

local api = vim.api

local S = {
  buf = nil,
  win = nil,
  root = nil,
  prev_win = nil,

  -- true while the user is typing in the search bar (line 2, insert mode in S.win)
  search_active = false,
  -- Set true by <Esc> so InsertLeave knows to clear the filter
  _search_clear_on_leave = false,
  -- 1-based index into S.items of the "selected" result while searching
  _search_cursor = nil,
  -- 1-based buffer line to move to after search exits (set by <CR>)
  _post_search_row = nil,

  -- S.items[i] lives at buffer line i+1 (1-based), row i (0-based)
  items = {},
  open_dirs = {},

  git = {},
  filter = nil,
  marks = {},
  recent_roots = {},

  ns = api.nvim_create_namespace("explorer_tree"),
  git_ns = api.nvim_create_namespace("explorer_git"),
  mark_ns = api.nvim_create_namespace("explorer_marks"),
  hdr_ns = api.nvim_create_namespace("explorer_header"),
  match_ns = api.nvim_create_namespace("explorer_match"),

  icon_fn = nil,
  build_tok = 0,
  close_fn = nil,
  width_expanded = false,

  -- Path to move the cursor to after the next build completes.
  -- Set by M.reveal(); consumed and cleared by render._reveal_cursor().
  _reveal_target = nil,
}

return S
