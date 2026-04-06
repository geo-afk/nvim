-- =============================================================================
--  plugins/ts-autotag.lua  ·  nvim-ts-autotag
-- =============================================================================
vim.pack.add({ { src = "https://github.com/windwp/nvim-ts-autotag" } })

local ok, autotag = pcall(require, "nvim-ts-autotag")
if not ok then return end

autotag.setup({
  opts = {
    enable_close          = true,
    enable_rename         = true,
    enable_close_on_slash = false,
  },
  per_filetype = {
    html = { enable_close = true },
  },
})
