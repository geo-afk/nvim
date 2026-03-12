return {
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
    notify_on_error = true,
    log_level = vim.log.levels.WARN, -- DEBUG → WARN for less spam (change back if troubleshooting)
    format_on_save = function(bufnr)
      local disable_filetypes = { c = true, cpp = true } -- Add more if needed, e.g., rust = true
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil -- no format on save
      end

      return {
        timeout_ms = 1500, -- Slightly higher for larger files / slower formatters
        lsp_format = 'fallback', -- Modern key (lsp_fallback still works, but lsp_format preferred in recent docs)
      }
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      javascript = { 'prettierd' },
      typescript = { 'prettierd' }, -- Fixed typo (removed trailing space)
      typescriptreact = { 'prettierd' },
      javascriptreact = { 'prettierd' },
      go = {
        'gofumpt',
        'goimports',
        'golines',
        -- stop_after_first = true,  -- Uncomment if you want to stop after first successful one
      },
      sql = { 'sleek' }, -- Rely on lsp_fallback for sqls if you prefer LSP formatting
      css = { 'prettierd' },
      html = { 'prettierd' },
      json = { 'prettierd' },
      python = { 'ruff' }, -- ruff handles format + organize imports
      -- Add more: e.g., markdown = { 'prettierd' }, yaml = { 'prettierd' }
    },
    formatters = {
      sleek = {
        command = 'sleek',
        args = {
          '--uppercase=true',
          '--indent-spaces=3',
          '--trailing-newline=false',
          -- '$FILENAME',  -- Usually not needed with stdin = true
        },
        stdin = true,
        -- inherit = true,  -- optional: inherit env vars if needed
      },
      -- Example: if you want to try sqlfmt later
      -- sqlfmt = {
      --   prepend_args = { '--dialect', 'clickhouse' },  -- or postgres, etc.
      -- },
    },
  },
}
