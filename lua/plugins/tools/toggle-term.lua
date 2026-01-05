return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
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
      -- Dynamic dir: use directory of previous buffer (if it's a normal file), else cwd
      dir = function()
        local prev_buf_path = vim.fn.bufname(vim.fn.bufnr '#')
        if prev_buf_path ~= '' and not prev_buf_path:match '^term://' then
          return vim.fn.fnamemodify(prev_buf_path, ':p:h')
        end
        return vim.fn.getcwd()
      end,
      on_open = function(term)
        term:send('clear', true)
        vim.cmd 'startinsert!'
      end,
    },
    config = function(_, opts)
      local toggleterm = require 'toggleterm'
      toggleterm.setup(opts)
      local Terminal = require('toggleterm.terminal').Terminal
      local terminals = {}
      local terminal_count = 5

      -- Common dynamic dir function (same logic as above)
      local function get_dynamic_dir()
        local prev_buf_path = vim.fn.bufname(vim.fn.bufnr '#')
        if prev_buf_path ~= '' and not prev_buf_path:match '^term://' then
          local dir = vim.fn.fnamemodify(prev_buf_path, ':p:h')
          if vim.fn.isdirectory(dir) == 1 then
            return dir
          end
        end
        return vim.fn.getcwd()
      end

      -- Common on_open (clean screen only)
      local function on_open_terminal(term)
        term:send('clear', true)
        vim.cmd 'startinsert!'
      end

      -- Create numbered terminal instances with dynamic dir
      for i = 2, terminal_count do
        terminals[i] = Terminal:new {
          direction = 'horizontal',
          hidden = false,
          display_name = 'Terminal ' .. i,
          dir = get_dynamic_dir(), -- Dynamic dir each time it's opened
          on_open = on_open_terminal,
        }
        _G['_TERMINAL_' .. i .. '_TOGGLE'] = function()
          terminals[i]:toggle()
        end
      end

      -- ========== SCOOTER INTEGRATION ==========
      -- (unchanged, as it uses float and specific cmd)
      local scooter_term = nil
      local function open_scooter()
        if not scooter_term then
          scooter_term = Terminal:new {
            cmd = 'scooter',
            direction = 'float',
            close_on_exit = true,
            on_open = function()
              vim.cmd 'startinsert!'
            end,
            on_exit = function()
              scooter_term = nil
            end,
          }
        end
        scooter_term:open()
      end

      _G.EditLineFromScooter = function(file_path, line)
        if scooter_term and scooter_term:is_open() then
          scooter_term:close()
        end
        local current_path = vim.fn.expand '%:p'
        local target_path = vim.fn.fnamemodify(file_path, ':p')
        if current_path ~= target_path then
          vim.cmd.edit(vim.fn.fnameescape(file_path))
        end
        vim.api.nvim_win_set_cursor(0, { line, 0 })
      end

      _G.OpenScooterSearchText = function(search_text)
        if scooter_term and scooter_term:is_open() then
          scooter_term:close()
        end
        local escaped_text = vim.fn.shellescape(search_text:gsub('\r?\n', ' '))
        scooter_term = Terminal:new {
          cmd = 'scooter --search-text ' .. escaped_text,
          direction = 'float',
          close_on_exit = true,
          on_open = function()
            vim.cmd 'startinsert!'
          end,
          on_exit = function()
            scooter_term = nil
          end,
        }
        scooter_term:open()
      end

      vim.keymap.set('n', '<leader>ts', open_scooter, { desc = 'Open scooter' })
      vim.keymap.set('v', '<leader>tr', '"ay<ESC><cmd>lua OpenScooterSearchText(vim.fn.getreg("a"))<CR>', { desc = 'Search selected text in scooter' })

      -- ========== TERMINAL NAVIGATION ==========
      local function set_terminal_keymaps()
        local term_opts = { buffer = 0, noremap = true, silent = true }
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], term_opts)
        vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-W>h]], term_opts)
        vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-W>j]], term_opts)
        vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-W>k]], term_opts)
        vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-W>l]], term_opts)
      end

      vim.api.nvim_create_autocmd('TermOpen', {
        pattern = 'term://*',
        callback = function()
          set_terminal_keymaps()
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
          vim.opt_local.signcolumn = 'no'
        end,
      })

      -- ========== WHICH-KEY REGISTRATION ==========
      local ok, wk = pcall(require, 'which-key')
      if ok then
        local mappings = {
          { '<leader>t', group = 'Terminal' },
          { '<leader>tt', '<cmd>ToggleTerm<cr>', desc = 'Toggle Default Terminal' },
          { '<leader>t1', '<cmd>1ToggleTerm<cr>', desc = 'Terminal 1' },
          { '<leader>ts', desc = '🚀 Open Scooter' },
          { '<leader>tr', desc = '🔍 Search Selected Text (Scooter)', mode = 'v' },
        }
        for i = 2, terminal_count do
          table.insert(mappings, {
            '<leader>t' .. i,
            '<cmd>lua _TERMINAL_' .. i .. '_TOGGLE()<cr>',
            desc = 'Terminal ' .. i,
          })
        end
        wk.add(mappings)
      end
    end,
  },
}
