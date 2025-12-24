return {
  'HiPhish/rainbow-delimiters.nvim',
  event = 'VeryLazy',
  config = function()
    require('rainbow-delimiters.setup').setup {
      -- strategy = {
      --   [''] = 'rainbow-delimiters.strategy.global',
      --   vim = 'rainbow-delimiters.strategy.local',
      -- },
      -- query = {
      --   [''] = 'rainbow-delimiters',
      --   lua = 'rainbow-blocks',
      --   typescript = 'rainbow-parens',
      --   typescriptreact = 'rainbow-parens',
      --   tsx = 'rainbow-parens',
      -- },
      -- priority = {
      --   [''] = 110,
      --   lua = 210,
      -- },
      highlight = {
        'RainbowDelimiterRed',
        'RainbowDelimiterYellow',
        'RainbowDelimiterBlue',
        'RainbowDelimiterOrange',
        'RainbowDelimiterGreen',
        'RainbowDelimiterViolet',
        'RainbowDelimiterCyan',
      },
    }
  end,
}
