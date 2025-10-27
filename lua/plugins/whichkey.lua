return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 0,
    defaults = {},
    show_help = true,
    spec = {
      { '<leader>/', group = 'Find IN Current Buffer' },
      { '<leader>b', group = 'Buffer' },
      { '<leader>e', icon = { icon = '📁', hl = 'MiniIconsBrown' }, group = 'Snacks File Explorer' },
      { '<leader>c', group = 'Code' },
      { '<leader>d', group = 'Inline Diagnostics' },
      { '<leader>s', group = 'Search' },
      { '<leader>w', group = 'Session' },
      { '<leader>x', group = 'Diagnostics/Quickfix' },
      --     { "<leader><Tab>", group = "Tab" },
    },
  },
  keys = {
    {
      '<leader>?',
      function()
        require('which-key').show { global = false }
      end,
      desc = 'Buffer Local Keymaps (which-key)',
    },

    {
      '<leader>e',
      function()
        Snacks.explorer()
      end,
      -- desc = 'Toggle Snacks File Explorer',
    },
  },
}
