-- custom/explorer/config.lua

local M = {}

-- ── Tree connector style presets ──────────────────────────────────────────
--
--  'rounded'  (default)     'sharp'              'minimal'
--  ╰─ file.lua              └─ file.lua            file.lua
--  ├─ foo.lua               ├─ foo.lua             foo.lua
--  │  ╰─ bar.lua            │  └─ bar.lua            bar.lua
--
M.TREE_STYLES = {
  rounded = { last = '╰─ ', branch = '├─ ', vert = '│  ', blank = '   ' },
  sharp   = { last = '└─ ', branch = '├─ ', vert = '│  ', blank = '   ' },
  minimal = { last = '  ', branch = '  ', vert = '  ', blank = '   ' },
  dots    = { last = '  · ', branch = '  · ', vert = '    ', blank = '    ' },
}

M.defaults = {
  width = 36,
  side = 'left',
  show_hidden = false,
  show_git = true,
  follow_file = true,
  auto_close = false,

  icons = { style = 'auto' },

  -- 'rounded' | 'sharp' | 'minimal' | 'dots' | leave nil for custom `tree`
  tree_style = 'rounded',

  -- Override individual connector keys (nil = derive from tree_style)
  tree = nil,

  -- Git sign glyphs (1 display-width each)
  git_signs = {
    modified  = '●',
    added     = '+',
    deleted   = '✗',
    renamed   = '»',
    untracked = '?',
    conflict  = '!',
    ignored   = '◌',
  },

  -- Show a match-count badge in the search bar when a filter is active
  search_count = true,

  keymaps = {
    toggle  = '<leader>e',
    -- reveal  = '<leader>E',

    open        = { '<CR>', 'l' },
    close_dir   = 'h',
    go_up       = '-',
    vsplit      = 'v',
    split       = 's',
    tab         = 't',
    add         = 'a',
    delete      = 'd',
    rename      = 'r',
    copy        = 'c',
    toggle_hidden = '.',
    refresh     = 'R',
    copy_path   = 'y',
    file_info   = 'i',
    mark        = 'm',
    collapse_all = 'W',
    expand_all  = 'E',
    git_stage   = 'gs',
    git_restore = 'gr',
    search      = '/',
    quit        = 'q',
    help        = '?',
  },
}

M.current = nil

function M.get()
  local c = M.current or M.defaults
  -- Lazily resolve tree connector table from style preset
  if not c.tree then
    local style = c.tree_style or 'rounded'
    -- shallow-copy to avoid mutating the defaults table
    c = vim.tbl_extend('force', {}, c, {
      tree = M.TREE_STYLES[style] or M.TREE_STYLES.rounded,
    })
  end
  return c
end

return M
