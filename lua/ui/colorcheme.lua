return {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      require('tokyonight').setup {
        style = 'storm',
        transparent = true,
        terminal_colors = true,
        styles = {
          comments = { italic = false },
          sidebars = 'transparent',
          floats = 'transparent',
        },
        -- Override specific highlight groups
        on_colors = function(colors)
          colors.comment = '#5c6370' -- Change comment color to a soft gray
          -- colors.bg = '#1a1b26' -- Even darker background
          -- colors.bg_sidebar = '#16161e' -- Match sidebar to darker tone
          -- colors.fg = '#c8d3f5' -- Softer text color
        end,
        on_highlights = function(highlights, colors)
          highlights.LspInlayHint = {
            fg = colors.comment, -- Or any other subtle color
            bg = 'NONE',
          }
        end,
      }
      require('notify').setup {
        merge_duplicates = true,
        background_colour = '#00000000',
      }
      -- vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  {
    'olimorris/onedarkpro.nvim',
    priority = 1000, -- load before other plugins
    config = function()
      require('onedarkpro').setup {
        colors = {},

        options = {
          transparency = true,
          terminal_colors = true,
          cursorline = true,
          underline = true,
          undercurl = true,
          bold = true,
          italic = true,
        },

        styles = {
          comments = 'italic',
          keywords = 'NONE',
          functions = 'bold',
          strings = 'NONE',
          variables = 'NONE',
        },

        highlights = {
          DiagnosticVirtualTextError = { italic = true, bold = false },
          DiagnosticVirtualTextWarn = { italic = true, bold = false },
          DiagnosticVirtualTextInfo = { italic = true, bold = false },
          DiagnosticVirtualTextHint = { italic = true, bold = false },
        },
        -- Load the theme
      }
      vim.cmd 'colorscheme onedark' -- or "onedark_vivid", "onedark_dark", "onelight"
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,

    config = function()
      require('catppuccin').setup {
        flavour = 'auto', -- latte, frappe, macchiato, mocha
        background = { -- :h background

          dark = 'mocha',
        },
        transparent_background = false, -- disables setting the background color.
        float = {
          transparent = false, -- enable transparent floating windows
          solid = false, -- use solid styling for floating windows, see |winborder|
        },
      }
    end,
  },
}
