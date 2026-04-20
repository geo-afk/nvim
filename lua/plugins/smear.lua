-- =============================================================================
--  plugins/smear.lua  ·  smear-cursor.nvim  (animated cursor trail)
-- =============================================================================

vim.pack.add({ { src = "https://github.com/sphamba/smear-cursor.nvim" } })

local ok, smear = pcall(require, "smear_cursor")
if not ok then
  return
end

smear.setup({
  stiffness = 0.4,
  trailing_stiffness = 0.2,
  trailing_exponent = 5,
  matrix_pixel_threshold = 0.5,
  gamma = 1,
  cursor_color = "#7aa2f7",
  legacy_computing_symbols_support = false,
  transparent_bg_fallback_color = "#303030",
  hide_target_hack = true,
})
