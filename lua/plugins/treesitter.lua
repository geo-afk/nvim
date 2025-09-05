return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs', -- Sets main module to use for opts
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  opts = {
    ensure_installed = {
      'c',
      'go',
      'vim',
      'lua',
      'bash',
      'html',
      'diff',
      'scss',
      'vimdoc',
      'luadoc',
      'angular',
      'markdown',
      'typescript',
      'javascript',
      'markdown_inline',
    },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { 'ruby' },
    },
    indent = { enable = true, disable = { 'ruby' } },

    -- Incremental selection
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<M-space>',
        node_incremental = '<M-space>',
        scope_incremental = false,
        node_decremental = '<bs>',
      },
    },

    -- Textobjects
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          -- Assignments
          ['a='] = { query = '@assignment.outer', desc = 'Select the outer part of an assignment' },
          ['i='] = { query = '@assignment.inner', desc = 'Select the inner part of an assignment' },
          ['l='] = { query = '@assignment.lhs', desc = 'Select the left hand side of an assignment' },
          ['r='] = { query = '@assignment.rhs', desc = 'Select the right hand side of an assignment' },

          -- Arguments
          ['aa'] = { query = '@parameter.outer', desc = 'Select the outer part of a parameter/argument' },
          ['ia'] = { query = '@parameter.inner', desc = 'Select the inner part of a parameter/argument' },

          -- Conditionals
          ['ai'] = { query = '@conditional.outer', desc = 'Select the outer part of a conditional' },
          ['ii'] = { query = '@conditional.inner', desc = 'Select the inner part of a conditional' },

          -- Loops
          ['al'] = { query = '@loop.outer', desc = 'Select the outer part of a loop' },
          ['il'] = { query = '@loop.inner', desc = 'Select the inner part of a loop' },

          -- Function/method definitions
          ['am'] = { query = '@function.outer', desc = 'Select the outer part of a function/method definition' },
          ['im'] = { query = '@function.inner', desc = 'Select the inner part of a function/method definition' },
          ['af'] = { query = '@call.outer', desc = 'Select the outer part of a function call' },
          ['if'] = { query = '@call.inner', desc = 'Select the inner part of a function call' },

          -- Class
          ['ac'] = { query = '@class.outer', desc = 'Select the outer part of a class' },
          ['ic'] = { query = '@class.inner', desc = 'Select the inner part of a class' },
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          [']f'] = { query = '@call.outer', desc = 'Next function call start' },
          [']m'] = { query = '@function.outer', desc = 'Next method/function def start' },
          [']c'] = { query = '@class.outer', desc = 'Next class start' },
          [']i'] = { query = '@conditional.outer', desc = 'Next conditional start' },
          [']l'] = { query = '@loop.outer', desc = 'Next loop start' },
          [']s'] = { query = '@scope', query_group = 'locals', desc = 'Next scope' },
        },
        goto_next_end = {
          [']F'] = { query = '@call.outer', desc = 'Next function call end' },
          [']M'] = { query = '@function.outer', desc = 'Next method/function def end' },
          [']C'] = { query = '@class.outer', desc = 'Next class end' },
          [']I'] = { query = '@conditional.outer', desc = 'Next conditional end' },
          [']L'] = { query = '@loop.outer', desc = 'Next loop end' },
        },
        goto_previous_start = {
          ['[f'] = { query = '@call.outer', desc = 'Prev function call start' },
          ['[m'] = { query = '@function.outer', desc = 'Prev method/function def start' },
          ['[c'] = { query = '@class.outer', desc = 'Prev class start' },
          ['[i'] = { query = '@conditional.outer', desc = 'Prev conditional start' },
          ['[l'] = { query = '@loop.outer', desc = 'Prev loop start' },
          ['[s'] = { query = '@scope', query_group = 'locals', desc = 'Prev scope' },
        },
        goto_previous_end = {
          ['[F'] = { query = '@call.outer', desc = 'Prev function call end' },
          ['[M'] = { query = '@function.outer', desc = 'Prev method/function def end' },
          ['[C'] = { query = '@class.outer', desc = 'Prev class end' },
          ['[I'] = { query = '@conditional.outer', desc = 'Prev conditional end' },
          ['[L'] = { query = '@loop.outer', desc = 'Prev loop end' },
        },
      },
    },
  },

  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)

    local ts_repeat_move = require 'nvim-treesitter.textobjects.repeatable_move'
    vim.keymap.set({ 'n', 'x', 'o' }, ';', ts_repeat_move.repeat_last_move)
    vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_opposite)
    vim.keymap.set({ 'n', 'x', 'o' }, 't', ts_repeat_move.builtin_t_expr)
    vim.keymap.set({ 'n', 'x', 'o' }, 'T', ts_repeat_move.builtin_T_expr)
  end,
}
