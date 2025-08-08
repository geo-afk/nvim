return {
  {
    'romgrk/barbar.nvim',
    dependencies = {
      'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
      'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
    },
    init = function()
      vim.g.barbar_auto_setup = false -- Disable auto-setup to customize
    end,
    opts = {
      icons = {
        filetype = { enabled = true },
        buffer_index = false,
        buffer_number = false,
        button = '×',
        modified = { button = '●' },
        pinned = { button = '📍' },
        gitsigns = {
          added = { enabled = true, icon = '+' },
          changed = { enabled = true, icon = '~' },
          deleted = { enabled = true, icon = '-' },
        },
      },
      clickable = true,
      auto_hide = false,
      sidebar_filetypes = {
        NvimTree = { event = 'BufWinLeave', text = 'File Explorer' },
      },
      sort = {
        method = 'insert_at_end',
      },
      separator = { left = '▎', right = '' },
    },
    keys = {
      { '<Tab>', '<Cmd>BufferNext<CR>', desc = 'Next buffer' },
      { '<S-Tab>', '<Cmd>BufferPrevious<CR>', desc = 'Previous buffer' },
      { '<A-<>', '<Cmd>BufferMovePrevious<CR>', desc = 'Move buffer left' },
      { '<A->>', '<Cmd>BufferMoveNext<CR>', desc = 'Move buffer right' },
      { '<A-1>', '<Cmd>BufferGoto 1<CR>', desc = 'Go to buffer 1' },
      { '<A-2>', '<Cmd>BufferGoto 2<CR>', desc = 'Go to buffer 2' },
      { '<A-3>', '<Cmd>BufferGoto 3<CR>', desc = 'Go to buffer 3' },
      { '<A-4>', '<Cmd>BufferGoto 4<CR>', desc = 'Go to buffer 4' },
      { '<A-5>', '<Cmd>BufferGoto 5<CR>', desc = 'Go to buffer 5' },
      { '<A-c>', '<Cmd>BufferClose<CR>', desc = 'Close buffer' },
      { '<C-p>', '<Cmd>BufferPick<CR>', desc = 'Pick buffer' },
      { '<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>', desc = 'Sort by buffer number' },
      { '<Space>bn', '<Cmd>BufferOrderByName<CR>', desc = 'Sort by name' },
      { '<Space>bd', '<Cmd>BufferOrderByDirectory<CR>', desc = 'Sort by directory' },
      { '<Space>bl', '<Cmd>BufferOrderByLanguage<CR>', desc = 'Sort by language' },
    },
    version = '^1.0.0',
  },
}
