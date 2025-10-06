local M = {}

local diagnostic_icons = {
  ERROR = '',
  WARN = '',
  HINT = '',
  INFO = '',
}

M.diagnostic = {
  severity_sort = true,
  float = {
    focusable = false,
    style = 'minimal',
    border = 'rounded',
    source = 'if_many',
    header = '',
    prefix = function(diagnostic)
      local level = vim.diagnostic.severity[diagnostic.severity]
      local prefix = (' %s '):format(diagnostic_icons[level])
      return prefix, 'Diagnostic' .. level:gsub('^%l', string.upper)
    end,
  },
  underline = { severity = vim.diagnostic.severity.ERROR },
  update_in_insert = false,
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = diagnostic_icons.HINT,
    },
  } or {},
  virtual_text = false, -- Disable inline virtual text
  virtual_lines = {
    enabled = true,
    current_line = true, -- Show virtual lines only for the current line
    severity = {
      min = vim.diagnostic.severity.WARN, -- Show warnings and errors
    },
    format = function(diagnostic)
      local level = vim.diagnostic.severity[diagnostic.severity]
      local icon = diagnostic_icons[level]
      local message = vim.split(diagnostic.message, '\n')[1]
      return ('%s %s '):format(icon, message)
    end,
  },
}

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
