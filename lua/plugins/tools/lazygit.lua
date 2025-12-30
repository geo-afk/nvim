return {
  {
    'floaty-term',
    dir = vim.fn.stdpath 'config' .. '/lua/custom/float_term',
    config = function()
      require('custom.float_term.term').setup {
        width_ratio = 0.7,
        height_ratio = 0.7,
        border = 'rounded',
        title = 'LazyGit',
      }
      vim.keymap.set('n', '<leader>vg', function()
        require('custom.float_term.term').create_terminal 'lazygit'
      end, { noremap = true, silent = true, desc = 'Lazygit' })
    end,
  },
}
