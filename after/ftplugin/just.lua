-- =============================================================================
-- after/ftplugin/just.lua
-- Justfile specific settings and keymaps
-- =============================================================================

local map = vim.keymap.set
local opts = { buffer = true, silent = true }

-- ── 1. Settings ──────────────────────────────────────────────────────────────
vim.opt_local.commentstring = "# %s"

-- ── 2. Keymaps ───────────────────────────────────────────────────────────────

-- Run just recipes via overseer
map("n", "<leader>jr", function()
  local ok, overseer = pcall(require, "overseer")
  if ok then
    overseer.run_template({ tags = { "just" } })
  else
    vim.cmd("terminal just")
  end
end, { buffer = true, desc = "Just: Run recipe" })

-- Run last overseer task (useful for repeated just runs)
map("n", "<leader>jl", "<cmd>OverseerRerunLast<CR>", { buffer = true, desc = "Just: Rerun last recipe" })

-- Format current file
map("n", "<leader>cf", function()
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({ bufnr = 0, lsp_format = "fallback" })
  else
    vim.lsp.buf.format()
  end
end, { buffer = true, desc = "LSP: Format buffer" })
