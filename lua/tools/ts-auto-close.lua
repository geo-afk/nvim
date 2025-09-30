return {
  {
    'windwp/nvim-ts-autotag',
    -- optionally lazy-load
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('nvim-ts-autotag').setup {
        opts = {
          enable_close = true, -- auto close tags
          enable_rename = true, -- auto rename paired tags
          enable_close_on_slash = false, -- auto close on trailing `</`
        },
        per_filetype = {
          html = {
            enable_close = true,
          },
          -- for e.g. xml or svelte, etc
        },
        aliases = {
          -- map some filetypes to use rules of others
          -- e.g. treat some custom or similar lang as html
          -- mylang = "html",
        },
      }
    end,
  },
}
