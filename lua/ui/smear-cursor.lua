return {
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      cursor_color = "#d3cdc3",
      transparent_bg_fallback_color = "#000000",
      normal_bg = "#282828",
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      use_floating_windows = true,
      legacy_computing_symbols_support = false,
    },
  },
  {
    "echasnovski/mini.animate",
    opts = {
      cursor = {
        enable = true,
        -- Faster animation
        timing = function(_, n)
          return 50 / n
        end,
      },
      scroll = {
        enable = true,
        timing = function(_, n)
          return 50 / n
        end,
      },
      resize = {
        enable = true,
        timing = function(_, n)
          return 50 / n
        end,
      },
      open = {
        enable = true,
        timing = function(_, n)
          return 50 / n
        end,
      },
      close = {
        enable = true,
        timing = function(_, n)
          return 50 / n
        end,
      },
    },
  },
}
