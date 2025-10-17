return {
  {
    'nvim-mini/mini.nvim',
    version = '*', -- Use the latest development version (main branch)
    config = function()
      -- Enable specific mini.nvim modules
      require('mini.pairs').setup()
      require('mini.align').setup {
        -- Whether to start in insert mode after alignment
        start_in_insert = false,

        -- Whether to highlight aligned region temporarily
        --
        highlight = true,

        -- Whether to show visual hints (column markers)
        show_hint = true,

        -- Optional keymaps (you can override default '<Leader>a' if you want)
        mappings = {
          start = 'ga', -- start alignment
          start_with_preview = 'gA', -- start with preview
        },
      }

      require('mini.ai').setup {
        n_lines = 500,
        custom_textobjects = {
          o = require('mini.ai').gen_spec.treesitter { -- code block
            a = { '@block.outer', '@conditional.outer', '@loop.outer' },
            i = { '@block.inner', '@conditional.inner', '@loop.inner' },
          },
          f = require('mini.ai').gen_spec.treesitter { a = '@function.outer', i = '@function.inner' }, -- function
          c = require('mini.ai').gen_spec.treesitter { a = '@class.outer', i = '@class.inner' }, -- class
          t = { '<([%p%w]-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' }, -- tags
          d = { '%f[%d]%d+' }, -- digits
          e = { -- Word with case
            { '%u[%l%d]+%f[^%l%d]', '%f[%S][%l%d]+%f[^%l%d]', '%f[%P][%l%d]+%f[^%l%d]', '^[%l%d]+%f[^%l%d]' },
            '^().*()$',
          },
          u = require('mini.ai').gen_spec.function_call(), -- u  "Usage"
          U = require('mini.ai').gen_spec.function_call { name_pattern = '[%w_]' }, -- without dot in function name
        },
      }

      require('mini.surround').setup {
        mappings = {
          add = 'sa', -- Add surrounding
          delete = 'sd', -- Delete surrounding
          find = 'sf', -- Find right surrounding
          find_left = 'sF', -- Find left surrounding
          highlight = 'sh', -- Highlight surrounding
          replace = 'sr', -- Replace surrounding
          update_n_lines = 'sn', -- Update `n_lines`

          suffix_last = 'l', -- Suffix to search with "prev" method
          suffix_next = 'n', -- Suffix to search with "next" method
        },
      }
    end,
  },
}
