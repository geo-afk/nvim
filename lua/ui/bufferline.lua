return {
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' }, -- for file icons
    version = '*',
    opts = {
      options = {
        numbers = 'none', -- no buffer numbers
        close_command = 'bdelete! %d', -- command to close buffer
        right_mouse_command = 'bdelete! %d',
        left_mouse_command = 'buffer %d',
        middle_mouse_command = 'bdelete! %d',
        indicator = {
          icon = '☕',
          style = 'icon', -- Highlight active buffer with underline for clarity
        },
        buffer_close_icon = '', -- Custom close icon
        modified_icon = '●', -- modified icon
        close_icon = '-', -- Icon for closing all the tabs
        left_trunc_marker = '', -- Marker for left overflow
        right_trunc_marker = '', -- Marker for right overflow
        max_name_length = 18, -- Set a max buffer name length
        max_prefix_length = 15, -- Set a max prefix length for truncated buffers
        tab_size = 20,
        diagnostics = 'nvim_lsp', -- optional LSP diagnostics
        offsets = {
          {
            filetype = 'NvimTree',
            text = 'File Explorer',
            highlight = 'Directory',
            text_align = 'left',
          },
        },
        diagnostics_indicator = function(count, level, diagnostics_dict, context)
          local error_count = diagnostics_dict.error or 0
          return error_count > 0 and '  ' .. error_count or ''
        end,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true, -- no global close icon
        show_tab_indicators = true,
        persist_buffer_sort = true,
        separator_style = 'thick', -- can also be 'slant' or 'thick'
        enforce_regular_tabs = true,
        color_icons = true,
        always_show_bufferline = true,
      },
      -- Subtle bracket-style highlighting for transparent backgrounds
      highlights = {
        -- Active buffer with bracket-like indicators
        buffer_selected = {
          fg = '#ffffff', -- bright white text
          bg = 'NONE',
          bold = true,
          italic = false,
        },
        -- Inactive buffers - more muted
        buffer = {
          fg = '#999999', -- medium gray
          bg = 'NONE',
          italic = true,
        },
        -- Modified indicators
        modified_selected = {
          fg = '#00ff88', -- bright green for modified active
          bg = 'NONE',
          bold = true,
        },
        modified = {
          fg = '#ffaa44', -- warm orange for modified inactive
          bg = 'NONE',
        },
        -- Close buttons
        close_button_selected = {
          fg = '#ff6b6b', -- red close button on active
          bg = 'NONE',
          bold = true,
        },
        close_button = {
          fg = '#777777',
          bg = 'NONE',
        },
        -- Custom separators for bracket effect
        separator_selected = {
          fg = '#00ddff', -- cyan brackets around active
          bg = 'NONE',
          bold = true,
        },
        separator = {
          fg = '#555555', -- subtle separators for inactive
          bg = 'NONE',
        },
        -- Diagnostics
        error_selected = {
          fg = '#ff4444',
          bg = 'NONE',
          bold = true,
        },
        error = {
          fg = '#cc4444',
          bg = 'NONE',
        },
        warning_selected = {
          fg = '#ffcc00',
          bg = 'NONE',
          bold = true,
        },
        warning = {
          fg = '#bb9900',
          bg = 'NONE',
        },
        -- Pick mode
        pick_selected = {
          fg = '#ff00ff', -- magenta for picking
          bg = 'NONE',
          bold = true,
          italic = true,
        },
        pick = {
          fg = '#cc00cc',
          bg = 'NONE',
          bold = true,
        },
        -- Background fill
        fill = {
          fg = '#333333',
          bg = 'NONE',
        },
      },
    },
    keys = {
      { '<Tab>', '<Cmd>BufferLineCycleNext<CR>', desc = 'Next buffer' },
      { '<S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', desc = 'Previous buffer' },
      { '<A-<>', '<Cmd>BufferLineMovePrev<CR>', desc = 'Move buffer left' },
      { '<A->>', '<Cmd>BufferLineMoveNext<CR>', desc = 'Move buffer right' },
      { '<A-1>', '<Cmd>BufferLineGoToBuffer 1<CR>', desc = 'Go to buffer 1' },
      { '<A-2>', '<Cmd>BufferLineGoToBuffer 2<CR>', desc = 'Go to buffer 2' },
      { '<A-3>', '<Cmd>BufferLineGoToBuffer 3<CR>', desc = 'Go to buffer 3' },
      { '<A-4>', '<Cmd>BufferLineGoToBuffer 4<CR>', desc = 'Go to buffer 4' },
      { '<A-5>', '<Cmd>BufferLineGoToBuffer 5<CR>', desc = 'Go to buffer 5' },
      { '<A-c>', '<Cmd>bdelete!<CR>', desc = 'Close buffer' },
      { '<C-p>', '<Cmd>BufferLinePick<CR>', desc = 'Pick buffer' },
      { '<Space>bb', '<Cmd>BufferLineSortByBufferNumber<CR>', desc = 'Sort by buffer number' },
      { '<Space>bn', '<Cmd>BufferLineSortByName<CR>', desc = 'Sort by name' },
      { '<Space>bd', '<Cmd>BufferLineSortByDirectory<CR>', desc = 'Sort by directory' },
      { '<Space>bl', '<Cmd>BufferLineSortByExtension<CR>', desc = 'Sort by language/extension' },
    },
  },
}
