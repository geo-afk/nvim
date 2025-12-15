return {
  'geo-afk/tabline.nvim',
  config = function()
    require('tabline').setup {
      enabled = true,
      separator = '▎', -- Modern separator
      close = '', -- Clean close icon
      modified = '●', -- Simple dot for modified
      hide_misc = true, -- Hide non-file buffers}
      min_visible = 10, -- Always show at least 3 buffers (default: 3)
      max_visible = 15, -- Never show more than 10 buffers (default: 10, 0 = unlimited)
    }
  end,
}
