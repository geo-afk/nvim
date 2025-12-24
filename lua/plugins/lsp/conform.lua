return {
  -- Autoformat
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    -- {
    --   '<leader>f',
    --   function()
    --     require('conform').format { async = true, lsp_format = 'fallback' }
    --   end,
    --   mode = '',
    --   desc = '[F]ormat buffer',
    -- },
  },
  opts = {
    notify_on_error = true,
    log_level = vim.log.levels.DEBUG,
    format_on_save = function(bufnr)
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      else
        return {
          timeout_ms = 1000,
          lsp_fallback = true,
        }
      end
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      javascript = { 'prettierd' },
      typescript = { 'prettierd ' },
      typescriptreact = { 'prettierd' },
      javascriptreact = { 'prettierd' },
      go = {
        'gofumpt',
        'goimports',
        'golines',
      },
      sql = { 'sleek' },
      -- sql = { 'sleek', 'sqlfmt' },
      css = { 'prettierd' },
      html = { 'prettierd' },
      -- ✓ prettierd
      htmlangular = { 'prettierd' },
      json = { 'prettierd' },
      python = { 'ruff' },
      -- python = { "isort", "black" },
    },
    formatters = {

      -- sqlfmt = {
      --   append_args = { '--dialect', 'clickhouse' },
      -- },
      sleek = {
        command = 'sleek',
        args = {
          '--uppercase=true',
          '--indent-spaces=3',
          '--trailing-newline=false',
          -- '$FILENAME',
        },
        stdin = true,
      },
    },
  },
}
