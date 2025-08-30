return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons', -- using devicons
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    enabled = true, -- markdown rendering is enabled by default
    -- You can tweak highlight groups, heading styles, etc. here if you want
  },
  keys = {
    {
      '<leader>mp', -- toggle markdown preview
      function()
        local render = require 'render-markdown'
        if render.is_enabled() then
          render.disable()
        else
          render.enable()
        end
      end,
      desc = 'Toggle Markdown Preview',
    },
  },
}
