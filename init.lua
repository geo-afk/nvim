-- =============================================================================
--  Neovim 0.12 Configuration  ·  init.lua
--  Requires: Neovim >= 0.12.0
--
--  Module load order matters:
--   1. plugins  – vim.pack declares & syncs plugins first
--   2. options  – set vim.opt values (some depend on plugin state)
--   3. keymaps  – global key bindings
--   4. autocmds – event-driven behaviour
--   5. lsp      – language-server setup
--   6. ui       – visual / UX layer (ui2, winborder, statusline …)
-- =============================================================================

-- Guard: abort with a clear message on old Neovim.
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("This config requires Neovim >= 0.12.  Current: " .. tostring(vim.version()), vim.log.levels.ERROR)
  return
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ── Bootstrap modules ────────────────────────────────────────────────────────
require("config.options")
require("plugins") -- lua/plugins/init.lua → requires each plugin file
require("config.keymaps")
require("config.autocmds")
require("config.lsp") -- native LSP server configs (vim.lsp.config/enable)
require("config.ui") -- ui2, float demos, Lua API showcases

-- custom utilities
require("custom.explorer").setup()
require("custom.lazygit").setup()
require("custom.cmdline").setup()
require("custom.code_action").setup()
require("custom.lsp_keymapper").setup()
require("custom.statusline").setup()
require("custom.tabline").setup()
require("custom.autoclose").setup()
require("custom.glow").setup()
require("custom.image_view").setup()

--terminal_manager
require("custom.terminal")
