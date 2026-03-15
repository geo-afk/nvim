return {
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = "nvim-treesitter", mods = { "nvim-treesitter" } },
        { path = "mason.nvim", mods = { "mason", "mason-core", "mason-registry", "mason-vendor" } },
        { path = "lazydev.nvim", mods = { "" } },
        { path = "LuaSnip", mods = { "luasnip" } },
        { path = "friendly-snippets", mods = { "snippets" } }, -- has vimscript
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
