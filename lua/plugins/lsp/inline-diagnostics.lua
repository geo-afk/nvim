return {
  'inline_diagnostic',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/diagnostics',
  config = function()
    local inline_diag = require 'custom.diagnostics'
    inline_diag.setup {
      preset = 'bubble', -- or 'bubble', 'sleek', 'minimal'
      theme = 'tokyo', -- or 'tokyo', 'nord', 'dracula', 'gruvbox'
      use_background = true, -- Colored backgrounds
      show_source = true, -- Show source like [eslint]
      throttle_ms = 100,
      multiline = {
        enabled = true,
        max_lines = 2,
        separator = ' 󰇘 ', -- Diamond separator
      },
    }

    -- Manual commands
    -- Manual controls
    vim.keymap.set('n', '<leader>dt', function()
      inline_diag.toggle()
    end, { desc = 'Toggle Diagnostics' })
    vim.keymap.set('n', '<leader>de', function()
      inline_diag.enable()
    end, { desc = 'Enable Diagnostics' })
    vim.keymap.set('n', '<leader>dd', function()
      inline_diag.disable()
    end, { desc = 'Disable Diagnostics' })

    -- Debug
    vim.keymap.set('n', '<leader>ds', function()
      vim.print(inline_diag.status())
    end, { desc = 'Show Diagnostics Status' })
  end,
}
