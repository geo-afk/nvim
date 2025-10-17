local M = {}

M.mason_tool_install = {
  -- Go tools
  'gofumpt',
  'goimports',
  'golines',
  'gotests',
  'staticcheck',
  'biome',
  -- General formatters/linters
  -- 'prettier',
  'prettierd',
  'stylua',
  -- 'eslint_d', -- Faster than eslint
  'gotests',
  'iferr',
  -- 'sqruff',
  'gomodifytags',
  -- Optional: Add based on your needs
  -- "jsonls",
  -- "marksman", -- Markdown LSP
}

M.mason_lsp = {
  'lua_ls',
  'gopls',
  'cssls',
  'typos_lsp',
  'sqls',
  'html',
  'angularls',
  'tailwindcss',
  'ts_ls',
}

return M
