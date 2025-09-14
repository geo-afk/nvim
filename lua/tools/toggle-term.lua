return {
  {
    'akinsho/toggleterm.nvim',
    version = 'v4.*',
    event = 'VeryLazy',
    opts = {
      size = function(term)
        if term.direction == 'horizontal' then
          return 17
        end
      end,
      open_mapping = [[<C-\>]],
      direction = 'horizontal',
      close_on_exit = true,
      on_open = function(term)
        local prev_buf_path = vim.fn.bufname(vim.fn.bufnr '#')
        local dir = (prev_buf_path ~= '' and not prev_buf_path:match '^term://') and vim.fn.fnamemodify(prev_buf_path, ':p:h') or vim.fn.getcwd()
        if dir and dir ~= '' and vim.fn.isdirectory(dir) == 1 then
          term:send('cd ' .. vim.fn.fnameescape(dir) .. ' ; clear', true)
        else
          term:send('clear', true)
        end
        vim.cmd 'startinsert!'
      end,
    },
    config = function(_, opts)
      local toggleterm = require 'toggleterm'
      toggleterm.setup(opts)

      local Terminal = require('toggleterm.terminal').Terminal
      local terminals = {}
      local terminal_count = 4 -- Configurable number of terminals

      -- Common on_open function
      local function on_open_terminal(term)
        local prev_buf_path = vim.fn.bufname(vim.fn.bufnr '#')
        local dir = (prev_buf_path ~= '' and not prev_buf_path:match '^term://') and vim.fn.fnamemodify(prev_buf_path, ':p:h') or vim.fn.getcwd()
        if dir and dir ~= '' and vim.fn.isdirectory(dir) == 1 then
          term:send('cd ' .. vim.fn.fnameescape(dir) .. ' ; clear', true)
        else
          term:send('clear', true)
        end
        vim.cmd 'startinsert!'
      end

      -- Create terminal instances
      for i = 2, terminal_count do
        terminals[i] = Terminal:new {
          direction = 'horizontal',
          hidden = false,
          display_name = 'Terminal ' .. i,
          on_open = on_open_terminal,
        }
        -- Define toggle functions dynamically
        _G['_TERMINAL_' .. i .. '_TOGGLE'] = function()
          terminals[i]:toggle()
        end
      end

      -- Terminal navigation keymaps
      local function set_terminal_keymaps()
        local term_opts = { buffer = 0, noremap = true, silent = true }
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], term_opts)
        vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-W>h]], term_opts)
        vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-W>j]], term_opts)
        vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-W>k]], term_opts)
        vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-W>l]], term_opts)
      end

      -- Set terminal buffer options and keymaps
      vim.api.nvim_create_autocmd('TermOpen', {
        pattern = 'term://*',
        callback = function()
          set_terminal_keymaps()
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
          vim.opt_local.signcolumn = 'no'
        end,
      })

      -- Register which-key mappings
      local wk = require 'which-key'
      local mappings = {
        { '<leader>t', group = 'Terminal', icon = '' },
        { '<leader>tt', '<cmd>ToggleTerm<cr>', desc = 'Toggle Default Terminal' },
        { '<leader>t1', '<cmd>1ToggleTerm<cr>', desc = 'Terminal 1' },
      }
      for i = 2, terminal_count do
        table.insert(mappings, {
          '<leader>t' .. i,
          '<cmd>lua _TERMINAL_' .. i .. '_TOGGLE()<cr>',
          desc = 'Terminal ' .. i,
        })
      end
      wk.add(mappings)
    end,
  },
}
