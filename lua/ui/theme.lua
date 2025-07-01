return {
  {
    -- Optional: Configure global transparency for Neovim UI
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha", -- Use a theme that supports transparency
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      transparent_background = true,
      integrations = {
        dropbar = { enabled = true, color_mode = true },
        telescope = true,
        native_lsp = { enabled = true },
      },
      highlight_overrides = {
        mocha = function(colors)
          return {
            Comment = { fg = colors.overlay1, style = { "italic" } },
          }
        end,
      },
    },
  },
  {
    -- Apply global transparency settings
    "xiyaowong/transparent.nvim",
    config = function()
      require("transparent").setup({
        groups = {
          "Normal",
          "NormalNC",
          "NonText",
          "SignColumn",
          "StatusLine",
          "StatusLineNC",
          "VertSplit",
          "TabLine",
          "TabLineFill",
          "TabLineSel",
          "Pmenu",
          "PmenuSel",
          "FloatBorder",
          "NormalFloat",
        },
        extra_groups = {
          "DropBarMenuNormal",
          "DropBarMenuNormalFloat",
          "DropBarMenuBorder",
          "DropBarIconUIIndicator",
          "DropBarKind",
        },
        exclude_groups = {},
      })
    end,
  },
}
