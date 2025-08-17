return {
  'rmagatti/auto-session',
  lazy = false,

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/Documents', '~/Desktop', '~/Music', '/' },
    -- log_level = 'debug',
  },

  config = function()
    vim.keymap.set('n', '<leader>ws', '<cmd>SessionSave<CR>', { desc = 'Save Session  for auto session root dir' })
  end,
}
