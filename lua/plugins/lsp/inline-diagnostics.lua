return {
  'inline_diagnostic',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/diagnostics',
  config = function()
    local inline_diag = require 'custom.diagnostics'
    inline_diag.setup {
      position = 'eol',
      -- Smart truncation settings
      eol_max_length = 150, -- Max chars before truncation
      truncate_multiline = true, -- Remove line breaks

      -- Right-aligned wrapping (NEW!)
      right_align_wrapped = true, -- Keep wrapped lines on the right
      wrap_at_column = 150, -- Where to wrap
      min_right_margin = 5, -- Space from edge

      -- What to show and in what order
      show_code = true, -- Show error codes [E123]
      show_source = true, -- Show source (eslint, tsc, etc.)
      priority_order = { 'code', 'severity', 'message', 'source' },

      -- Visual style
      preset = 'modern', -- modern, minimal, powerline, ghost
      show_diagnostic_count = true, -- Show "+2" for multiple errors
    }

    -- Manual commands
    -- Manual controls
    vim.keymap.set('n', '<leader>do', function()
      inline_diag.toggle()
    end, { desc = 'Toggle Diagnostics' })

    vim.keymap.set('n', '<leader>dt', function()
      inline_diag.cycle_preset()
    end, { desc = 'Cycle Preset Theme' })

    vim.keymap.set('n', '<leader>dp', function()
      inline_diag.cycle_position()
    end, { desc = 'Cycle Diagnostics Position' })

    -- Debug
    vim.keymap.set('n', '<leader>ds', function()
      vim.print(inline_diag.status())
    end, { desc = 'Show Diagnostics Status' })
  end,
}
