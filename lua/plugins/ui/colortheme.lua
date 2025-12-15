return {
  'geo-afk/theme.nvim',
  lazy = false,
  priority = 1000,
  config = function()
    require('theme').setup()
    -- vim.cmd.colorscheme 'cd-theme'
  end,
}
