return {
  'rmagatti/auto-session',
  lazy = false,

  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { '~/', '~/Documents', '~/Desktop', '~/Music', '/' },
    -- log_level = "debug",
  },

  config = function(_, opts)
    -- setup
    require('auto-session').setup(opts)

    -- keymaps for sessions
    local map = function(keys, cmd, desc)
      vim.keymap.set('n', keys, cmd, { desc = desc })
    end

    map('<leader>ws', '<cmd>AutoSession save"<CR>', 'Save session')
    map('<leader>wr', '<cmd>AutoSession restore<CR>', 'Restore last session')
    map('<leader>wd', '<cmd>AutoSession delete<CR>', 'Delete current session')
  end,
}
