return {
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
    keys = {
      {
        ']t',
        function()
          require('todo-comments').jump_next()
        end,
        desc = 'Next todo',
      },
      {
        '[t',
        function()
          require('todo-comments').jump_prev()
        end,
        desc = 'Previous todo',
      },
      {
        '<leader>st',
        function()
          if vim.g.picker_engine == 'fzf' then
            require('todo-comments.fzf').todo()
          elseif vim.g.picker_engine == 'snacks' then
            ---@diagnostic disable-next-line: undefined-field
            Snacks.picker.todo_comments()
          else
            vim.cmd 'TodoTelescope'
          end
        end,
        desc = 'Todo',
      },
    },
  },
}
