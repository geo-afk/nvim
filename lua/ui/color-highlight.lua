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
        -- custom_colors = {
        --   -- DaisyUI defaults (example values, check your setup)
        --   { label = 'primary', color = '#570DF8' },
        --   { label = 'secondary', color = '#F000B8' },
        --   { label = 'accent', color = '#37CDBE' },
        --   { label = 'neutral', color = '#3D4451' },
        --   { label = 'info', color = '#3ABFF8' },
        --   { label = 'success', color = '#36D399' },
        --   { label = 'warning', color = '#FBBD23' },
        --   { label = 'error', color = '#F87272' },
        -- },
      }
    end,
  },
}
