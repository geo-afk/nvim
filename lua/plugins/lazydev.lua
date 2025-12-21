return {
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = 'snacks.nvim', words = { 'Snacks' } },
        -- {
        --   path = 'lazy.nvim',
        --   files = vim.tbl_map(function(file)
        --     return vim.fn.fnamemodify(file, ':p:t')
        --   end, vim.split(vim.fn.glob(vim.fn.stdpath 'config' .. '/lua/plugins/**/*.lua'), '\n')),
        -- },
      },
    },
  },
}
