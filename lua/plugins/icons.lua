-- =============================================================================
--  plugins/icons.lua  ·  nvim-web-devicons + mini.icons
-- =============================================================================
vim.pack.add({
  -- { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/echasnovski/mini.icons" },
})

-- local ok, devicons = pcall(require, "nvim-web-devicons")
-- if ok then devicons.setup({ default = true }) end

local mok, mini_icons = pcall(require, "mini.icons")
if mok then
  mini_icons.setup()
end
