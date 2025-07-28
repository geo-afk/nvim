local M = {}

M.diagnostic = {
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚 ",
      [vim.diagnostic.severity.WARN] = "󰀪 ",
      [vim.diagnostic.severity.INFO] = "󰋽 ",
      [vim.diagnostic.severity.HINT] = "󰌶 ",
    },
  } or {},
  virtual_text = {
    source = "if_many",
    spacing = 2,
    format = function(diagnostic)
      return diagnostic.message
    end,
  },
}

M.mason_tool_install = {
  -- Go tools
  "gofumpt",
  "goimports",
  "golines",
  "gotests",
  "staticcheck",
  -- General formatters/linters
  "prettier",
  "stylua",
  "eslint_d", -- Faster than eslint
  -- Optional: Add based on your needs
  -- "jsonls",
  -- "marksman", -- Markdown LSP
}

M.mason_lsp = {
  "lua_ls",
  "gopls",
  "cssls",
  "sqlls",
  "html",
  "angularls",
  "tailwindcss",
  "ts_ls", -- Modern TypeScript/JavaScript LSP (replaces tsserver)
  -- Removed typos_lsp as it's often problematic
}

M.on_attach = function(client, bufnr)
  if client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

return M
