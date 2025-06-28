return {
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    cond = vim.g.neovide == nil, -- Disable in Neovide, as it has native cursor animations
    opts = {
      -- General settings
      smear_between_buffers = true, -- Smear cursor when switching buffers or windows
      smear_between_neighbor_lines = true, -- Smear when moving within or to neighbor lines
      scroll_buffer_space = true, -- Draw smear in buffer space when scrolling
      legacy_computing_symbols_support = true, -- Enable if your font supports legacy computing symbols (e.g., Cascadia Code)

      -- Animation settings
      stiffness = 0.8, -- Controls cursor movement responsiveness [0, 1]
      trailing_stiffness = 0.5, -- Controls trailing effect [0, 1]
      stiffness_insert_mode = 0.6, -- Stiffness in insert mode [0, 1]
      trailing_stiffness_insert_mode = 0.6, -- Trailing stiffness in insert mode [0, 1]
      damping = 0.65, -- Controls bounciness [0, 1]
      distance_stop_animating = 0.5, -- Stop animation when smear is within this distance (chars) from cursor
      time_interval = 17, -- Animation frame rate (milliseconds)

      -- Color settings
      cursor_color = "#d3cdc3", -- Cursor color (set to "none" to use highlight group at cursor)
      transparent_bg_fallback_color = "#303030", -- Fallback color for transparent backgrounds
      cterm_cursor_colors = { 240, 245, 250, 255 }, -- Color gradient for non-termguicolors
      cterm_bg = 235, -- Background color for non-termguicolors

      -- Optional: Disable smear in specific filetypes
      filetypes_disabled = {},

      -- Hide real cursor for better effect in terminals
      hide_target_hack = true,
    },
    specs = {
      -- Disable mini.animate cursor animations to avoid conflicts
      {
        "echasnovski/mini.animate",
        optional = true,
        opts = {
          cursor = {
            enable = false,
          },
        },
      },
    },
  },
}
