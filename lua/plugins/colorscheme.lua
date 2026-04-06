-- =============================================================================
--  plugins/colorscheme.lua  ·  tokyonight
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/tokyonight.nvim" } })

local ok, tokyonight = pcall(require, "tokyonight")
if ok then
  tokyonight.setup({
    style       = "night",
    transparent = false,
    styles      = {
      comments  = { italic = true },
      keywords  = { italic = true },
      functions = {},
      variables = {},
    },
    on_highlights = function(hl, _c)
      -- [0.12-new] nvim_set_hl update=true used in autocmds.lua for partial
      -- updates; here we set full definitions via the theme hook.
      hl.DiffTextAdd = { bg = "#1c3a2a", fg = "#73daca" }
    end,
  })
end

if not pcall(vim.cmd, "colorscheme tokyonight-night") then
  vim.cmd("colorscheme habamax")
end
