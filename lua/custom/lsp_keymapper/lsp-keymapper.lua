--- plugin/lsp-keymapper.lua
--- Neovim auto-load shim.  This file is sourced automatically by Neovim's
--- runtime loader.  It does *nothing* unless the user calls setup() – this
--- prevents any side effects for users who load the plugin but haven't
--- configured it yet.
if vim.g.loaded_lsp_keymapper then
  return
end
vim.g.loaded_lsp_keymapper = true

-- No-op: all initialisation happens in setup().
-- Users who prefer an out-of-the-box experience with zero config can add:
--
--   require("lsp-keymapper").setup()
--
-- anywhere in their init.lua / init.vim after their LSP configuration.
