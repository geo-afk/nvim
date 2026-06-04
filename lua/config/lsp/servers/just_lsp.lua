---@module "lspconfig"
---@type vim.lsp.Config
return {
  cmd = { "just-lsp" },
  filetypes = { "just" },
  root_markers = { "justfile", ".justfile", "Justfile" },
}
