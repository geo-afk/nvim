local prefix = '<leader>x'

return {
  'folke/trouble.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  cmd = 'Trouble',
  opts = {
    padding = false,
    use_diagnostic_signs = true,
    modes = {
      diagnostics_buffer = {
        mode = 'diagnostics', -- inherit from diagnostics mode
        filter = { buf = 0 }, -- filter diagnostics to the current buffer
      },
      -- show only most severe available diagnostics
      cascade = {
        mode = 'diagnostics',
        filter = function(items)
          local severity = vim.diagnostic.severity.HINT
          for _, item in ipairs(items) do
            severity = math.min(severity, item.severity)
          end
          return vim.tbl_filter(function(item)
            return item.severity == severity
          end, items)
        end,
      },
    },
  },
}
