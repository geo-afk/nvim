return {
  {
    'floaty-term',
    dir = vim.fn.stdpath 'config' .. '/lua/custom/floating_buffer',
    config = function()
      require('custom.floating_buffer.terminal').setup {
        width_ratio = 0.7,
        height_ratio = 0.7,
        border = 'rounded',
        title = 'LazyGit',
      }
      vim.keymap.set('n', '<leader>vg', function()
        require('custom.floating_buffer.terminal').create_terminal 'lazygit'
      end, { noremap = true, silent = true, desc = 'Lazygit' })
    end,
  },
}
