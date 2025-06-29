return {
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      -- Cursor color. Defaults to Cursor highlight group
      cursor_color = "#d3cdc3",
      transparent_bg_fallback_color = "#000000",
      -- Background color. Defaults to Normal highlight group
      normal_bg = "#282828",

      -- Smear cursor when switching buffers
      smear_between_buffers = true,

      -- Smear cursor when switching windows
      smear_between_neighbor_lines = true,

      -- Use floating windows to display smears over splits
      use_floating_windows = true,

      -- Set to `true` if your font supports legacy computing symbols (block unicode symbols)
      legacy_computing_symbols_support = false,
    },
  },
  {
    "echasnovski/mini.animate",
    opts = {
      -- Cursor path
      cursor = {
        enable = true,
        timing = function(_, n)
          return 150 / n
        end,
      },

      -- Vertical scroll
      scroll = {
        enable = true,
        timing = function(_, n)
          return 150 / n
        end,
      },

      -- Window resize
      resize = {
        enable = true,
        timing = function(_, n)
          return 150 / n
        end,
      },

      -- Window open/close
      open = {
        enable = true,
        timing = function(_, n)
          return 150 / n
        end,
      },

      -- Window close
      close = {
        enable = true,
        timing = function(_, n)
          return 150 / n
        end,
      },
    },
  },
}
