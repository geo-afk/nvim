-- =============================================================================
--  plugins/lazydev.lua  ·  lazydev.nvim (Lua/Neovim type annotations)
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/lazydev.nvim" } })

local ok, lazydev = pcall(require, "lazydev")
if not ok then return end

lazydev.setup({
  library = {
    { path = "${3rd}/luv/library",     words = { "vim%.uv" } },
    { path = "nvim-treesitter",        mods  = { "nvim-treesitter" } },
    { path = "mason.nvim",             mods  = { "mason", "mason-core", "mason-registry", "mason-vendor" } },
    { path = "lazydev.nvim",           mods  = { "" } },
    { path = "LuaSnip",               mods  = { "luasnip" } },
    { path = "nvim-lspconfig",         mods  = { "lspconfig" } },
    { path = "friendly-snippets",      mods  = { "snippets" } },
    vim.fn.stdpath("data") .. "/site/pack/core/opt/blink.cmp/lua/",
  },
})
