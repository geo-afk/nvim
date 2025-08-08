local has_git = vim.fn.executable 'git' == 1

-- local function get_current_directory(state)
--   local node = state.tree:get_node()
--   if node.type ~= 'directory' or not node:is_expanded() then
--     node = state.tree:get_node(node:get_parent_id())
--   end
--   return node:get_id()
-- end
--
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- Enables file type icons
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree toggle<CR>', desc = 'NeoTree toggle', silent = true },
    { '<leader>bf', ':Neotree buffers toggle<CR>', desc = 'NeoTree buffers', silent = true },
    { '<leader>ff', ':Neotree filesystem toggle<CR>', desc = 'NeoTree filesystem', silent = true },
    { '<leader>sf', ':Neotree filesystem reveal_force_cwd<CR>', desc = 'Search files', silent = true },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = 'rounded',
    enable_git_status = has_git,
    enable_diagnostics = true,
    open_files_do_not_replace_types = { 'terminal', 'trouble', 'qf' },
    sort_case_insensitive = false,
    default_source = 'filesystem',
    sources = {
      'filesystem',
      'buffers',
      'git_status',
    },
    source_selector = {
      winbar = true,
      statusline = false,
      show_scrolled_off_parent_node = false,
      sources = {
        {
          source = 'filesystem',
          display_name = ' 󰉓 Files ',
        },
        {
          source = 'buffers',
          display_name = ' 󰈚 Buffers ',
        },
      },
      content_layout = 'start',
      tabs_layout = 'equal',
      truncation_character = '…',
      highlight_tab = 'NeoTreeTabInactive',
      highlight_tab_active = 'NeoTreeTabActive',
      highlight_background = 'NeoTreeTabInactive',
    },

    event_handlers = {
      -- Close neo-tree when opening a file.
      {
        event = 'file_opened',
        handler = function()
          vim.cmd 'Neotree close'
        end,
      },
    },
    window = {
      position = 'left',
      width = 30,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        ['<cr>'] = 'open',
        ['<2-LeftMouse>'] = 'open',
        ['<esc>'] = 'cancel',
        ['P'] = { 'toggle_preview', config = { use_float = true } },
        ['S'] = 'open_split',
        ['s'] = 'open_vsplit',
        ['t'] = 'open_tabnew',
        ['w'] = 'open_with_window_picker',
        ['z'] = 'close_all_nodes',
        ['Z'] = 'expand_all_nodes',
        ['a'] = {
          'add',
          config = {
            show_path = 'none',
          },
        },
        ['A'] = 'add_directory',
        ['d'] = 'delete',
        ['r'] = 'rename',
        ['y'] = 'copy_to_clipboard',
        ['x'] = 'cut_to_clipboard',
        ['p'] = 'paste_from_clipboard',
        ['c'] = 'copy',
        ['m'] = 'move',
        ['q'] = 'close_window',
        ['R'] = 'refresh',
        ['?'] = 'show_help',
        ['<'] = 'prev_source',
        ['>'] = 'next_source',
        ['/'] = 'fuzzy_finder',
        ['D'] = 'fuzzy_finder_directory',
        ['f'] = 'filter_on_submit',
        ['<c-x>'] = 'clear_filter',
        -- Custom simple mappings
        ['\\'] = 'close_window',
        ['h'] = 'close_node',
        ['l'] = 'open',
      },
    },
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      group_empty_dirs = false,
      hijack_netrw_behavior = 'open_current',
      use_libuv_file_watcher = has_git,
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_name = {
          '.git',
          'node_modules',
        },
        never_show = {
          '.DS_Store',
          'thumbs.db',
        },
      },
      window = {
        mappings = {
          -- Find file in path.
          -- ['gf'] = function(state)
          --   LazyVim.pick('files', { cwd = get_current_directory(state) })()
          -- end,
        },
      },
    },
    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      group_empty_dirs = true,
      show_unloaded = true,
      window = {
        mappings = {
          ['dd'] = 'buffer_delete',
          ['<bs>'] = 'navigate_up',
          ['.'] = 'set_root',
        },
      },
    },
    git_status = {
      window = {
        position = 'float',
        mappings = {
          ['A'] = 'git_add_all',
          ['gu'] = 'git_unstage_file',
          ['ga'] = 'git_add_file',
          ['gr'] = 'git_revert_file',
          ['gc'] = 'git_commit',
          ['gp'] = 'git_push',
          ['gg'] = 'git_commit_and_push',
        },
      },
    },
    default_component_configs = {
      container = {
        enable_character_fade = true,
      },
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = '│',
        last_indent_marker = '└',
        highlight = 'NeoTreeIndentMarker',
      },
      icon = {
        folder_closed = '▸', -- Smaller arrow icons
        folder_open = '▾',
        folder_empty = '',
        folder_empty_open = '',
        default = '',
        highlight = 'NeoTreeFileIcon',
      },
      modified = {
        symbol = '+',
        highlight = 'NeoTreeModified',
      },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
        highlight = 'NeoTreeFileName',
      },
      git_status = {
        symbols = {
          added = '✚',
          modified = '~',
          deleted = '✖',
          renamed = '➜',
          untracked = '★',
          ignored = '◌',
          unstaged = '✗',
          staged = '✓',
          conflict = 'x',
        },
      },
    },
  },
}
