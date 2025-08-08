return {
  {
    -- Show indentation guides, even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = {
        char = '│', -- or '▏' for a thinner look
        tab_char = '│',
      },
      whitespace = {
        remove_blankline_trail = false,
        highlight = { 'Whitespace', 'NonText' },
      },
      scope = {
        enabled = true,
        show_start = true,
        show_end = false,
        highlight = { 'Function', 'Label' },
      },
      exclude = {
        filetypes = { 'help', 'terminal', 'dashboard', 'lazy', 'NvimTree' },
        buftypes = { 'terminal', 'nofile' },
      },
    },
  },
}
