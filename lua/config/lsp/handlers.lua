local M = {}

-- Get capabilities with blink.cmp integration
function M.get_capabilities()
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  return require("blink.cmp").get_lsp_capabilities(original_capabilities)
end

-- Common on_attach function
function M.on_attach(client, bufnr)
  -- Enable inlay hints if supported
  if client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end

  -- Add any other common on_attach logic here
end

-- Setup keymaps (called once globally)
function M.setup_keymaps()
  vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Get Descriptions" })
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })
  vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Go to References" })
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Actions" })
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename Symbol" })
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to Implementation" })
  vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature Help" })

  vim.keymap.set("n", "<leader>ci", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end, { desc = "Toggle Inlay Hints" })
end

return M
