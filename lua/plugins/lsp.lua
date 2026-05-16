-- =============================================================================
--  plugins/lsp.lua  ·  LSP plugin declarations + config/lsp wiring
--
--  This file adds nvim-lspconfig via vim.pack and then delegates all server
--  configuration to config/lsp.lua (the 0.12 vim.lsp.config/enable module).
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/neovim/nvim-lspconfig" },
})

local map = vim.keymap.set
local diagnostic_jump_float = function(diagnostic, bufnr)
  if diagnostic then
    vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor" })
  end
end

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "LSP: Definition" })

-- Diagnostics
map("n", "<leader>df", vim.diagnostic.open_float, { desc = "Open diagnostic float" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, on_jump = diagnostic_jump_float })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, on_jump = diagnostic_jump_float })
end, { desc = "Prev diagnostic" })
map("n", "<leader>dq", vim.diagnostic.setqflist, { desc = "Diagnostics → quickfix" })
map("n", "<leader>ds", function()
  vim.notify("Diagnostics: " .. vim.diagnostic.status(), vim.log.levels.INFO)
end, { desc = "Diagnostic status" })
map("n", "<leader>dw", function()
  vim.lsp.buf.workspace_diagnostics()
end, { desc = "Workspace diagnostics" })

-- Compatibility shims for muscle-memory commands removed in 0.12
vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", { desc = "[0.12] LSP info" })
vim.api.nvim_create_user_command("LspRestart", "lsp restart", { desc = "[0.12] Restart LSP" })
vim.api.nvim_create_user_command("LspStop", "lsp stop", { desc = "[0.12] Stop LSP" })
vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd("edit " .. vim.fs.joinpath(vim.fn.stdpath("state"), "lsp.log"))
end, { desc = "[0.12] Open LSP log" })
