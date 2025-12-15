return {
  {
    'geo-afk/colorhint.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('colorhint').setup {
        -- render = 'both',
        -- enable_tailwind = true,
        -- -- tailwind_render_background = true,
        -- -- context_aware = true,
        filetype_overrides = {
          -- javascript = { enable_named_colors = true },
          -- typescript = { enable_named_colors = false },
          -- lua = { enable_named_colors = false },
          -- python = { enable_named_colors = false },

          css = { enable_named_colors = false },
          html = { enable_named_colors = false },
        },
      }
    end,
  },
}
