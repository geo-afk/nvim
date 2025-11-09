return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 0,
    defaults = {},
    show_help = true,
    spec = {
      { '<leader>e', icon = { icon = '📁', hl = 'MiniIconsBrown' }, group = 'Snacks File Explorer' },
      { '<leader>/', group = 'Find IN Current Buffer' },
      { '<leader>x', group = 'Diagnostics/Quickfix' },
      { '<leader>d', group = 'Inline Diagnostics' },
      { '<leader>q', group = 'Quick-Fix List' },
      { '<leader>p', group = 'Plugins/UI' },
      { '<leader>w', group = 'Session' },
      { '<leader>b', group = 'Buffer' },
      { '<leader>s', group = 'Search' },
      { '<leader>m', icon = { icon = '🔖', hl = 'MiniIconsOrange' }, group = 'Marks' },
      { '<leader>i', icon = { icon = 'ⓘ', hl = 'MiniIconsBlue' }, group = 'Info' }, -- UTF info symbol
      { '<leader>c', group = 'Code' },
      { '<leader>u', icon = { icon = '↩️', hl = 'MiniIconsPurple' }, group = 'Undo' },
      { '<leader>v', group = 'Git' },
      { 'm', group = 'Marks' },
      { 'g', group = 'Goto' },
      -- { "<leader><Tab>", group = "Tab" },
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
