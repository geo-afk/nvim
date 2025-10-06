if vim.g.neovide then
  vim.keymap.set('n', '<C-s>', ':w<CR>') -- Save
  vim.keymap.set('v', '<C-c>', '"+y') -- Copy
  vim.keymap.set('n', '<C-v>', '"+P') -- Paste normal mode
  vim.keymap.set('v', '<C-v>', '"+P') -- Paste visual mode
  vim.keymap.set('c', '<C-v>', '<C-R>+') -- Paste command mode
  vim.keymap.set('i', '<C-v>', '<ESC>l"+Pli') -- Paste insert mode

  -- Font (adjust size/path as needed; use a Nerd Font  icons)
  vim.o.guifont = 'JetBrainsMono Nerd Font:h10.5'

  -- Basic rendering  crisp text
  vim.opt.linespace = 0
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_text_gamma = 0.0 -- Keeps text sharp
  vim.g.neovide_text_contrast = 1.0

  -- Minimal padding  a clean edge
  vim.g.neovide_padding_top = 0
  vim.g.neovide_padding_bottom = 0
  vim.g.neovide_padding_right = 0
  vim.g.neovide_padding_left = 1

  -- Transparency: Focused at 0.9, unfocused more ghostly at 0.2
  vim.g.neovide_opacity = 0.9
  vim.g.neovide_normal_opacity = 0.1

  -- Blur  that modern glassmorphism (test on Windows; set false if laggy)
  vim.g.neovide_window_blurred = true

  -- Floating windows: Subtle shadows and blur  depth
  vim.g.neovide_floating_shadow = true
  vim.g.neovide_floating_z_height = 10
  vim.g.neovide_light_angle_degrees = 45
  vim.g.neovide_light_radius = 5
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_floating_corner_radius = 0.01 -- Barely rounded  polish

  -- Smooth, quick animations
  vim.g.neovide_position_animation_length = 0.15
  vim.g.neovide_scroll_animation_length = 0.15
  vim.g.neovide_cursor_animation_length = 0.13

  -- Theme and perf
  vim.g.neovide_theme = 'auto'
  vim.g.neovide_refresh_rate = 60

  -- Fun cursor effect
  vim.g.neovide_cursor_vfx_mode = 'ripple'
  vim.g.neovide_cursor_trail_size = 0.3 -- Light trail  movement feel
end
