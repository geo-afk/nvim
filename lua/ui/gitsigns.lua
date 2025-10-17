return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },

    -- Enable blame info
    current_line_blame = true,

    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = 'eol', -- eol | overlay | right_align
      delay = 1000,
      ignore_whitespace = false,
    },

    -- Format for blame text
    -- current_line_blame_matter = '     <author> • <author_time:%Y-%m-%d %H:%M> • <summary>',

    preview_config = {
      border = 'single',
      style = 'minimal',
      relative = 'cursor',
      row = 0,
      col = 1,
    },
  },
}
