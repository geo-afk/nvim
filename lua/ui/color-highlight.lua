return {
  {
    'brenoprata10/nvim-highlight-colors',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('nvim-highlight-colors').setup {
        render = 'virtual', -- other options: "foreground" or "virtual" or "background"
        enable_named_colors = true,
        enable_tailwind = true,
        virtual_symbol = '◼',

        -- virtual_symbol_prefix = " ",
        -- virtual_symbol_suffix = "",
        ---Set virtual symbol position()
        ---@usage 'inline'|'eol'|'eow'
        ---inline mimics VS Code style
        ---eol stands for `end of column` - Recommended to set `virtual_symbol_suffix = ''` when used.
        ---eow stands for `end of word` - Recommended to set `virtual_symbol_prefix = ' ' and virtual_symbol_suffix = ''` when used.
        virtual_symbol_position = 'inline',
      }
    end,
  },
}

-- #fff
--
-- #f4d123
