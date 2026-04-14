-- =============================================================================
--  plugins/lsp.lua  ·  LSP plugin declarations + config/lsp wiring
--
--  This file adds nvim-lspconfig via vim.pack and then delegates all server
--  configuration to config/lsp.lua (the 0.12 vim.lsp.config/enable module).
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/neovim/nvim-lspconfig" },
})

-- config/lsp.lua is required by init.lua after plugins/.
-- We enable inlay hints globally here once the LSP subsystem is ready.
vim.api.nvim_create_autocmd("LspAttach", {
  group    = vim.api.nvim_create_augroup("plugins_lsp_inlay", { clear = true }),
  once     = true,
  callback = function()
    -- [0.11+] Global inlay hints – toggle per-buffer with <leader>ch
    pcall(vim.lsp.inlay_hint.enable, true)
  end,
})

-- Compatibility shims for muscle-memory commands removed in 0.12
vim.api.nvim_create_user_command("LspInfo",    "checkhealth vim.lsp", { desc = "[0.12] LSP info" })
vim.api.nvim_create_user_command("LspRestart", "lsp restart",          { desc = "[0.12] Restart LSP" })
vim.api.nvim_create_user_command("LspStop",    "lsp stop",             { desc = "[0.12] Stop LSP" })
vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd("edit " .. vim.fs.joinpath(vim.fn.stdpath("state"), "lsp.log"))
end, { desc = "[0.12] Open LSP log" })
