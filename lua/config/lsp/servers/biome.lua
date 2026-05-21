---@module "lspconfig"
---@type vim.lsp.Config
return {
  cmd = { "biome", "lsp-proxy" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "css",
    "svelte",
    "vue",
    "astro",
    "graphql",
  },
  -- Biome should only attach if a configuration file is present
  root_markers = { "biome.json", "biome.jsonc" },
  single_file_support = false,
}
