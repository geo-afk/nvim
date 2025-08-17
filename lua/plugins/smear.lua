return {
  'sphamba/smear-cursor.nvim',
  opts = {
    -- Optional tuning values
    -- stiffness = 0.5,
    -- trailing_stiffness = 0.5,
    -- matrix_pixel_threshold = 0.5,

    -- Use default cursor color instead of 'none' (avoids unknown char issue)
    cursor_color = nil,

    -- Usually not needed anymore — can cause weird "unknown char"
    legacy_computing_symbols_support = false,

    -- Keep this if you have a transparent terminal background
    transparent_bg_fallback_color = '#303030',

    -- Helps hide flicker
    hide_target_hack = true,
  },
}
