-- lazy.nvim
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {
    -- apply globally
    views = {
      popup = {
        border = {
          style = 'rounded', -- double-line borders look thicker than "rounded"
          highlight = 'FloatBorder',
          title = ' NOICE ', -- title text
          title_pos = 'center', -- center the title
        },
      },
      cmdline_popup = {
        border = {
          style = 'rounded', -- "single", "double", "rounded", "solid", "shadow"
          highlight = 'FloatBorder',
          title = ' CMD ', -- bold-looking title
          title_pos = 'center',
        },
      },
    },
  },
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify', -- optional
  },
  config = function(_, opts)
    require('noice').setup(opts)

    -- make border/title colors thicker/bolder
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#7aa2f7', bold = true })
    vim.api.nvim_set_hl(0, 'NoiceCmdlinePopupBorder', { fg = '#bb9af7', bold = true })
    vim.api.nvim_set_hl(0, 'NoiceCmdlinePopupTitle', { fg = '#bb9af7', bold = true })
  end,
}
