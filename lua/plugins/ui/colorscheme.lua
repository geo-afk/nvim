return {

  {
    "AstroNvim/astrotheme",
    -- enabled = false,
    lazy = false,
    priority = 1000,
    config = function()
      require("astrotheme").setup({
        palette = "astrodark",
        style = {
          transparent = true,       -- Bool value, toggles transparency.
          inactive = false,
          italic_comments = false,
          float = true,                      -- Bool value, toggles floating windows background colors.
          neotree = true,                    -- Bool value, toggles neo-trees background color.
          border = true,                     -- Bool value, toggles borders.
          title_invert = true,               -- Bool value, swaps text and background colors.
          simple_syntax_colors = true,       -- Bool value, simplifies the amounts of colors used for syntax highlighting.
        },
      })
      vim.cmd("colorscheme astrotheme")

      vim.schedule(function()
        require("custom.extensions.highlights")
      end)
    end,
  }
}

