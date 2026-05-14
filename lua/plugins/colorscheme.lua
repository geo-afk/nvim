-- =============================================================================
--  plugins/colorscheme.lua  ·  tokyonight
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/tokyonight.nvim" } })
vim.pack.add({ { src = "https://github.com/geo-afk/theme.nvim" } })
vim.pack.add({ { src = "https://github.com/AstroNvim/astrotheme" } })

-- local c_ok, c_theme = pcall(require, "theme")
local ok, tokyonight = pcall(require, "tokyonight")
local a_ok, astro = pcall(require, "astrotheme")

if ok then
  tokyonight.setup({
    style = "night",
    transparent = false,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = {},
      variables = {},
    },
    on_highlights = function(hl, _)
      -- [0.12-new] nvim_set_hl update=true used in autocmds.lua for partial
      -- updates; here we set full definitions via the theme hook.
      hl.DiffTextAdd = { bg = "#1c3a2a", fg = "#73daca" }
    end,
  })
end

-- if c_ok then
--   c_theme.setup()
-- end

if a_ok then
  astro.setup()
  vim.cmd("colorscheme astrodark")
end
