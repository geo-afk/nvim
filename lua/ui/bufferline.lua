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
        middle_mouse_command = nil,
        buffer_close_icon = '×', -- close icon
        modified_icon = '●', -- modified icon
        close_icon = '×', -- global close icon
        left_trunc_marker = '◀',
        right_trunc_marker = '▶',
        max_name_length = 30,
        max_prefix_length = 15, -- prefix used when a buffer name is duplicate
        tab_size = 21,
        diagnostics = 'nvim_lsp', -- optional LSP diagnostics
        offsets = {
          {
            filetype = 'NvimTree',
            text = 'File Explorer',
            highlight = 'Directory',
            text_align = 'left',
          },
        },
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = false, -- no global close icon
        show_tab_indicators = true,
        persist_buffer_sort = true,
        separator_style = 'thick', -- can also be 'slant' or 'thick'
        enforce_regular_tabs = false,
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
