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
