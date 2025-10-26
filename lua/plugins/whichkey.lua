return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 0,
    defaults = {},
    show_help = true,
    spec = {
      --     -- individual keymaps
      --     { "<leader>K", icon = { icon = "󰋽", hl = "MiniIconsBlue" } },
      --     { "<leader>cm", icon = { icon = "󱁤", hl = "MiniIconsGrey" } },
      --     -- groups
      --     { "<leader>d", group = "Divider", icon = { icon = "", hl = "MiniIconsGrey" } },
      --     { "<leader>g", group = "Git" },
      --     { "<leader>gh", group = "Hunks" },
      --     { "<leader>n", group = "Noice" },
      --     { "<leader>r", group = "Run", icon = { icon = "", hl = "MiniIconsRed" } },
      --     { "<leader>t", group = "Test", icon = { icon = "󰱑", hl = "MiniIconsGreen" } },
      --     { "<leader>T", group = "Terminal" },
      --     { "<leader>u", group = "UI" },
      { '<leader>/', group = 'Find IN Current Buffer' },
      { '<leader>b', group = 'Buffer' },
      { '<leader>e', group = 'Snacks File Explorer' },
      { '<leader>c', group = 'Code' },
      { '<leader>d', group = 'Inline Diagnostics' },
      { '<leader>s', group = 'Search' },
      { '<leader>w', group = 'Session' },
      { '<leader>x', group = 'Diagnostics/Quickfix' },
      --     { "<leader><Tab>", group = "Tab" },
    },
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
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
