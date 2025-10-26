return {
  'sphamba/smear-cursor.nvim',
  opts = {
    stiffness = 0.4,
    trailing_stiffness = 0.2,
    matrix_pixel_threshold = 0.5,

    trailing_exponent = 5,

    gamma = 1,

    -- Use default cursor color instead of 'none' (avoids unknown char issue)
    cursor_color = '#7aa2f7',

    -- Usually not needed anymore — can cause weird "unknown char"
    legacy_computing_symbols_support = false,

    -- Keep this if you have a transparent terminal background
    transparent_bg_fallback_color = '#303030',

    -- Helps hide flicker
    hide_target_hack = true,
  },
}
