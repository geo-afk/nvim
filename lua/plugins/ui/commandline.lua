return {
  {
    'geo-afk/cmdline.nvim',
    -- event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('cmdline').setup {
        completion = {
          smart_enabled = true,
          lsp_enabled = true,
          telescope_enabled = true,
          treesitter_enabled = true,
        },
      }
    end,
  },
}
