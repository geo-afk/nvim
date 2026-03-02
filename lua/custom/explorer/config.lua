-- custom/explorer/config.lua

local M = {}

M.defaults = {
  width = 36,
  side = 'left',
  show_hidden = false,
  show_git = true,
  follow_file = true,
  auto_close = false,

  icons = { style = 'auto' },

  -- Rounded, modern tree connectors (inspired by VSCode/snacks style)
  tree = {
    last = '╰─ ',
    branch = '├─ ',
    vert = '│  ',
    blank = '   ',
  },

  -- Git sign glyphs (1 display-width each; space appended automatically)
  git_signs = {
    modified = '✎',
    added = '✚', -- new file
    deleted = '✗',
    renamed = '→',
    untracked = '?',
    conflict = '!',
    ignored = '◌',
  },

  keymaps = {
    toggle = '<leader>e',
    reveal = '<leader>E',

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
    mark = 'm',
    collapse_all = 'W',
    expand_all = 'E',
    git_stage = 'gs',
    git_restore = 'gr',
    search = '/',
    quit = 'q',
    help = '?',
  },
}

M.current = nil

function M.get()
  return M.current or M.defaults
end

return M
