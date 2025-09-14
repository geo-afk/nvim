return {
  -- Autoformat
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    notify_on_error = false,
    log_level = vim.log.levels.DEBUG,
    format_on_save = function(bufnr)
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      else
        return {
          timeout_ms = 500,
          lsp_format = 'fallback',
        }
      end
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      javascript = { 'biome' },
      typescript = { 'biome' },
      typescriptreact = { 'biome' },
      javascriptreact = { 'biome' },
      go = {
        'goimports',
        'gofumpt',
        'golines',
      },
      sql = { 'sqruff' },
      css = { 'biome' },
      html = { 'biome' },
      json = { 'biome' },
      -- python = { "isort", "black" },
    },
    formatters = {
      sqruff = {
        command = 'sqruff',
        args = { 'fix', '--config', vim.fn.stdpath 'config' .. '\\.sqruff', '$FILENAME' },
        stdin = false,
      },
    },
  },
}
