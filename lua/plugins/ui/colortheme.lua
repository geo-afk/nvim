-- return {
--   'geo-afk/theme.nvim',
--   lazy = false,
--   priority = 1000,
--   config = function()
--     require('theme').setup()
--     -- vim.cmd.colorscheme 'cd-theme'
--   end,
-- }

return {
  'folke/tokyonight.nvim',
  lazy = false,
  priority = 1000,
  opts = {},
  config = function()
    vim.cmd.colorscheme 'tokyonight-night'
  end,
}
