-- Start with base LSP capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()

-- Try to enhance with blink.cmp if available
local ok, blink = pcall(require, "blink.cmp")
if ok and blink and type(blink.get_lsp_capabilities) == "function" then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

-- Ensure nested tables exist before mutation
capabilities.textDocument = capabilities.textDocument or {}
capabilities.textDocument.completion = capabilities.textDocument.completion or {}
capabilities.textDocument.completion.completionItem = capabilities.textDocument.completion.completionItem or {}

-- Safe capability extensions
capabilities.textDocument.completion.completionItem.snippetSupport = true

capabilities.textDocument.colorProvider = {
  dynamicRegistration = false,
}

capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

---@module "lspconfig"
---@type vim.lsp.Config
return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = {
    "html",
    "htmlangular",
    "css",
    "scss",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_markers = {
    "tailwind.config.js",
    "tailwind.config.ts",
    "postcss.config.js",
    "package.json",
    ".git",
  },
  capabilities = capabilities,
  ---@type lspconfig.settings.tailwindcss
  settings = {
    tailwindCSS = {
      emmetCompletions = true,
      validate = true,
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidScreen = "error",
        invalidVariant = "error",
        invalidConfigPath = "error",
        invalidTailwindDirective = "error",
        recommendedVariantOrder = "warning",
      },
      classAttributes = {
        "class",
        "className",
        "classList",
        "ngClass",
        ":class",
      },
      experimental = {
        classRegex = {
          "tw`([^`]*)`",
          "tw\\(([^)]*)\\)",
          "@apply\\s+([^;]*)",
          'class="([^"]*)"',
          'className="([^"]*)"',
          ':class="([^"]*)"',
          "@class\\(([^)]*)\\)",
        },
      },
    },
  },
}
