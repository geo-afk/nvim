return {
  "navarasu/onedark.nvim",
  lazy = false,
  priority = 1000, -- load before other UI plugins
  config = function()
    require("onedark").setup({
      style = "deep", -- options: 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer', 'light'
      transparent = true,
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,

      -- Options are italic, bold, underline, none
      code_style = {
        comments = "italic",
        keywords = "none",
        functions = "bold",
        strings = "none",
        variables = "none",
      },

      -- Plugins Config --
      diagnostics = {
        darker = true, -- darker colors for diagnostic
        undercurl = true, -- use undercurl instead of underline for diagnostics
        background = true, -- use background color for virtual text
      },
    })

    require("onedark").load()
  end,
}
