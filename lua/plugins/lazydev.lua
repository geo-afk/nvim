-- =============================================================================
--  plugins/lazydev.lua  ·  lazydev.nvim (Lua/Neovim type annotations)
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/lazydev.nvim" } })

local ok, lazydev = pcall(require, "lazydev")
if not ok then
  return
end

lazydev.setup({
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    { path = "lazydev.nvim", mods = { "lazydev" } },
    { path = "nvim-treesitter", mods = { "nvim-treesitter" } },
    { path = "mason.nvim", mods = { "mason", "mason-core", "mason-registry", "mason-vendor" } },
    { path = "LuaSnip", mods = { "luasnip" } },
    { path = "friendly-snippets", mods = { "snippets" } },
    { path = "which-key.nvim", mods = { "which-key" } },
    { path = "trouble.nvim", mods = { "trouble" } },
    { path = "telescope.nvim", mods = { "telescope" } },
    { path = "overseer.nvim", mods = { "overseer" } },
    { path = "nvim-dap", mods = { "dap" } },
    { path = "blink.cmp", mods = { "blink.cmp" } },
    vim.fn.stdpath("data") .. "/site/pack/core/opt/blink.cmp/lua/",
  },
  enabled = function(root_dir)
    return vim.g.lazydev_enabled == nil and true or vim.g.lazydev_enabled
  end,
})
