-- explorer/config.lua

local M = {}

M.defaults = {
  width = 34,
  side = 'left', -- "left" | "right"
  show_hidden = false,
  show_git = true,
  follow_file = true,
  auto_close = false,

  -- "auto" | "mini" | "devicons" | "builtin" | "none"
  icons = { style = 'auto' },

  -- Unicode tree connectors
  tree = { last = '└ ', branch = '├ ', vert = '│ ', blank = '  ' },

  -- Git sign glyphs shown in the 2-char left column
  -- Each value is exactly 1 display-char; a space is appended automatically.
  git_signs = {
    modified = 'M', -- staged or unstaged changes
    added = 'A', -- new file staged
    deleted = 'D', -- deleted
    renamed = 'R', -- renamed
    untracked = '?', -- not tracked by git
    conflict = 'U', -- merge conflict / unmerged
    ignored = 'I', -- gitignored
  },

  keymaps = {
    -- Global (normal mode, everywhere)
    toggle = '<leader>e',
    reveal = '<leader>E',

    -- Buffer-local (only inside the explorer window)
    open = { '<CR>', 'l' },
    close_dir = 'h',
    go_up = '-',
    vsplit = 'v',
    split = 's',
    tab = 't',
    add = 'a',
    delete = 'd',
    rename = 'r',
    copy = 'c',
    toggle_hidden = '.',
    refresh = 'R',
    copy_path = 'y',
    file_info = 'i',
    mark = 'm', -- toggle mark on file (was <Space>, conflicted with leader)
    collapse_all = 'W',
    expand_all = 'E',
    git_stage = 'gs',
    git_restore = 'gr',
    search = '/',
    quit = 'q',
    help = '?',
  },
}

-- Runtime config (filled by setup())
M.current = nil

-- Helper: always return the live config or fall back to defaults
function M.get()
  return M.current or M.defaults
end

return M
