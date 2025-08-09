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
        background_colour = '#00000000',
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
  {
    'navarasu/onedark.nvim',
    lazy = false,
    priority = 1000, -- load before other UI plugins
    config = function()
      require('onedark').setup {
        style = 'deep', -- options: 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer', 'light'
        transparent = true,
        term_colors = true,
        ending_tildes = false,
        cmp_itemkind_reverse = false,

        -- Options are italic, bold, underline, none
        code_style = {
          comments = 'italic',
          keywords = 'none',
          functions = 'bold',
          strings = 'none',
          variables = 'none',
        },

        -- Plugins Config --
        diagnostics = {
          darker = true, -- darker colors for diagnostic
          undercurl = true, -- use undercurl instead of underline for diagnostics
          background = true, -- use background color for virtual text
        },
      }

      require('onedark').load()
    end,
  },
}
