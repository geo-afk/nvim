return {
  'geo-afk/dev-server',
  config = function()
    require('dev-server').setup {
      -- your configuration here

      window = {
        type = 'split', -- 'split', 'vsplit', or 'float'
        position = 'botright', -- 'topleft', 'topright', 'botleft', 'botright'
        size = 15, -- height for split, width for vsplit
      },
      keymaps = {
        toggle = '<leader>dt',
        restart = '<leader>dr',
        stop = '<leader>ds',
        status = '<leader>dS',
      },

      auto_start = false,

      notifications = {
        enabled = true,
        level = {
          start = vim.log.levels.INFO,
          stop = vim.log.levels.INFO,
          error = vim.log.levels.ERROR,
        },
      },

      -- Pre-configured servers
      servers = {
        -- Angular development server
        angular = {
          cmd = 'ng serve',
          detect = {
            marker = 'angular.json', -- ← this is usually enough
            -- filetypes = { "typescript", "html", "css", "scss" },  -- optional fallback
          },
          window = {
            type = 'split',
            position = 'botright',
            size = 20,
          },
        },
        -- go = {
        --   cmd = 'air .',
        --   window = {
        --     type = 'split',
        --     position = 'botright',
        --     size = 20,
        --   },
        -- },
      },
    }

    local dev_server = require 'dev-server'

    -- -- Show server status
    vim.keymap.set('n', '<leader>gi', ':DevServerStatus<CR>', { desc = '[D]ev [I]nfo: Show all servers' })
    --
    -- vim.keymap.set('n', '<leader>g+', function()
    --   vim.ui.input({ prompt = 'Server name: ' }, function(name)
    --     if not name or name == '' then
    --       return
    --     end
    --     vim.ui.input({ prompt = 'Command: ' }, function(cmd)
    --       if not cmd or cmd == '' then
    --         return
    --       end
    --       local success = dev_server.register(name, { cmd = cmd })
    --       if success then
    --         vim.notify("Server '" .. name .. "' registered", vim.log.levels.INFO)
    --       end
    --     end)
    --   end)
    -- end, { desc = '[D]ev [+] Register new server' })
  end,
}
