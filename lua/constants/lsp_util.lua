local M = {}

M.diagnostic = {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = {
    source = 'if_many',
    spacing = 2,
    format = function(diagnostic)
      local diagnostic_message = {
        [vim.diagnostic.severity.ERROR] = diagnostic.message,
        [vim.diagnostic.severity.WARN] = diagnostic.message,
        [vim.diagnostic.severity.INFO] = diagnostic.message,
        [vim.diagnostic.severity.HINT] = diagnostic.message,
      }
      return diagnostic_message[diagnostic.severity]
    end,
  },
}

M.mason_tool_install = {
  -- Go tools
  'gofumpt',
  'goimports',
  -- 'golines',
  'gotests',
  'staticcheck',
  -- General formatters/linters
  'prettier',
  'stylua',
  'eslint_d', -- Faster than eslint
  -- Optional: Add based on your needs
  -- "jsonls",
  -- "marksman", -- Markdown LSP
}

M.mason_lsp = {
  'lua_ls',
  'gopls',
  'cssls',
  'typos_lsp',
  'sqlls',
  'html',
  'angularls',
  'tailwindcss',
  'ts_ls', -- Modern TypeScript/JavaScript LSP (replaces tsserver)
  -- Removed typos_lsp as it's often problematic
}

return M
