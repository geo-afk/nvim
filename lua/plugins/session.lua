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

    map('<leader>ws', '<cmd>SessionSave<CR>', 'Save session')
    map('<leader>wr', '<cmd>SessionRestore<CR>', 'Restore last session')
    map('<leader>wf', '<cmd>SessionRestoreFromFile<CR>', 'Restore session from file')
    map('<leader>wd', '<cmd>SessionDelete<CR>', 'Delete current session')
  end,
}
