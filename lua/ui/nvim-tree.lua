return {
  'nvim-tree/nvim-tree.lua',
  version = '*',
  lazy = false,
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local function on_attach(bufnr)
      local api = require 'nvim-tree.api'
      local opts = function(desc)
        return { desc = 'nvim-tree: ' .. desc, noremap = true, silent = true, buffer = bufnr }
      end

      -- Navigation
      vim.keymap.set('n', 'l', api.node.open.edit, opts 'Open')
      vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts 'Close Directory')
      vim.keymap.set('n', 'v', api.node.open.vertical, opts 'Open: Vertical Split')
      vim.keymap.set('n', 's', api.node.open.horizontal, opts 'Open: Horizontal Split')

      -- File operations
      vim.keymap.set('n', 'a', api.fs.create, opts 'Create File/Dir')
      vim.keymap.set('n', 'd', api.fs.remove, opts 'Delete')
      vim.keymap.set('n', 'r', api.fs.rename, opts 'Rename')
      vim.keymap.set('n', 'x', api.fs.cut, opts 'Cut')
      vim.keymap.set('n', 'c', api.fs.copy.node, opts 'Copy')
      vim.keymap.set('n', 'p', api.fs.paste, opts 'Paste')
      vim.keymap.set('n', 'y', api.fs.copy.filename, opts 'Copy Name')
      vim.keymap.set('n', 'Y', api.fs.copy.relative_path, opts 'Copy Relative Path')
      vim.keymap.set('n', 'gy', api.fs.copy.absolute_path, opts 'Copy Absolute Path')

      -- Misc
      vim.keymap.set('n', 'R', api.tree.reload, opts 'Refresh')
      vim.keymap.set('n', '?', api.tree.toggle_help, opts 'Help')

      -- Go up in the folder hierarchy
      vim.keymap.set('n', 'u', api.tree.change_root_to_parent, opts 'Go Up One Folder')
    end

    require('nvim-tree').setup {
      sort_by = 'case_sensitive',
      view = {
        width = 31,
        side = 'left',
      },
      renderer = {

        group_empty = true,
        root_folder_label = function(path)
          return '📂 ' .. vim.fn.fnamemodify(path, ':t')
        end,
        highlight_git = true,
        highlight_opened_files = 'all',
        -- root_folder_label = true, -- Hide full root path
        indent_markers = {
          enable = true,
          inline_arrows = true,
          icons = {
            corner = '└',
            edge = '│',
            item = '│',
            bottom = '─',
            none = ' ',
          },
        },
        icons = {
          glyphs = {
            folder = {
              arrow_closed = '',
              arrow_open = '',
            },
            git = {
              unstaged = '✗',
              staged = '✓',
              unmerged = '',
              renamed = '➜',
              untracked = '★',
              deleted = '',
              ignored = '◌',
            },
          },
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
        },
      },
      filters = {
        dotfiles = false,
        custom = { '^.git$' },
      },
      git = {
        enable = true,
        ignore = false,
        timeout = 501,
      },
      update_focused_file = {
        enable = true,
        update_root = true, -- Automatically set tree root to file's folder
      },
      respect_buf_cwd = true,
      sync_root_with_cwd = true, -- Sync root to buffer cwd

      on_attach = on_attach,
    }

    vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
  end,
}
