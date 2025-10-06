return {
  'zongben/dbout.nvim',
  build = 'npm install',
  --this is optional if you disable telescope
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('dbout').setup {}
  end,
}
