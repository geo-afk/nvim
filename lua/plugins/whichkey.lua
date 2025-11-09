return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    delay = 0,
    defaults = {},
    show_help = true,
    spec = {
      { '<leader>e', icon = { icon = '⟟', hl = 'MiniIconsBrown' }, group = 'Snacks File Explorer' }, -- Folder-like / Structure
      { '<leader>/', icon = { icon = '∷', hl = 'MiniIconsYellow' }, group = 'Find In Current Buffer' }, -- Search / Filter
      { '<leader>x', icon = { icon = '!', hl = 'MiniIconsRed' }, group = 'Diagnostics/Quickfix' }, -- Warning
      { '<leader>d', icon = { icon = '⨁', hl = 'MiniIconsRed' }, group = 'Inline Diagnostics' }, -- Error/inline marker
      { '<leader>q', icon = { icon = '☰', hl = 'MiniIconsGrey' }, group = 'Quick-Fix List' }, -- List/Menu
      { '<leader>p', icon = { icon = '≡', hl = 'MiniIconsGreen' }, group = 'Plugins/UI' }, -- Settings/Gear
      { '<leader>w', icon = { icon = '⟲', hl = 'MiniIconsBlue' }, group = 'Session' }, -- Session restore/rotation
      { '<leader>r', icon = { icon = '⟲', hl = 'MiniIconsOrange' }, group = 'Replace' }, -- Replace/Redo
      { '<leader>b', icon = { icon = '▦', hl = 'MiniIconsCyan' }, group = 'Buffer' }, -- Document blocks
      { '<leader>s', icon = { icon = '⌕', hl = 'MiniIconsYellow' }, group = 'Search' }, -- Search lens (non-emoji)
      { '<leader>m', icon = { icon = '•', hl = 'MiniIconsOrange' }, group = 'Marks' }, -- Flag mark
      { '<leader>i', icon = { icon = 'i', hl = 'MiniIconsBlue' }, group = 'Info' }, -- Info
      { '<leader>c', icon = { icon = 'λ', hl = 'MiniIconsGreen' }, group = 'Code' }, -- Code/lambda
      { '<leader>u', icon = { icon = '↩', hl = 'MiniIconsPurple' }, group = 'Undo' }, -- Undo arrow
      { '<leader>v', icon = { icon = '⎇', hl = 'MiniIconsGreen' }, group = 'Git' }, -- Git branch symbol
      { 'm', icon = { icon = '◆', hl = 'MiniIconsOrange' }, group = 'Marks' }, -- Mark symbol
      { 'g', icon = { icon = '➜', hl = 'MiniIconsBlue' }, group = 'Goto' }, -- Arrow navigation
      -- { "<leader><Tab>", icon = { icon = '▤', hl = 'MiniIconsBrown' }, group = "Tab" },
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
      desc = 'Toggle Snacks File Explorer',
    },
  },
}
