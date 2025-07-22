return {
  {
    "akinsho/toggleterm.nvim",
    version = "v2.*",
    event = "VeryLazy",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<C-\>]], -- Toggle default terminal
      hide_numbers = true,
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = "float", -- Default to floating, but allow horizontal splits
      close_on_exit = true,
      shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "cmd.exe",
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Custom terminal instances
      local Terminal = require("toggleterm.terminal").Terminal

      -- Horizontal terminal instances
      local terminals = {
        powershell = Terminal:new({
          cmd = "pwsh",
          direction = "horizontal",
          hidden = true,
          display_name = "PowerShell",
        }),
        gitbash = Terminal:new({
          cmd = vim.fn.executable("bash") == 1 and "bash" or nil,
          direction = "horizontal",
          hidden = true,
          display_name = "Git Bash",
        }),
        cmd = Terminal:new({
          cmd = "cmd.exe",
          direction = "horizontal",
          hidden = true,
          display_name = "Command Prompt",
        }),
        python = Terminal:new({
          cmd = "python",
          direction = "horizontal",
          hidden = true,
          display_name = "Python REPL",
        }),
      }

      -- LazyGit terminal (floating for better UI)
      local lazygit = Terminal:new({
        cmd = "lazygit",
        direction = "float",
        hidden = true,
        display_name = "LazyGit",
      })

      -- Toggle functions
      function _POWERSHELL_TOGGLE()
        terminals.powershell:toggle()
      end

      function _GITBASH_TOGGLE()
        if terminals.gitbash.cmd then
          terminals.gitbash:toggle()
        else
          vim.notify("Git Bash not found!", vim.log.levels.WARN)
        end
      end

      function _CMD_TOGGLE()
        terminals.cmd:toggle()
      end

      function _PYTHON_TOGGLE()
        terminals.python:toggle()
      end

      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end

      -- Cycle through horizontal terminals
      local current_term_index = 1
      local term_keys = { "powershell", "gitbash", "cmd", "python" }
      function _CYCLE_HORIZONTAL_TERMINALS()
        if terminals[term_keys[current_term_index]].cmd then
          terminals[term_keys[current_term_index]]:toggle()
        else
          vim.notify(term_keys[current_term_index] .. " not available!", vim.log.levels.WARN)
        end
        current_term_index = current_term_index % #term_keys + 1
      end

      -- Open all horizontal terminals in splits
      function _OPEN_ALL_HORIZONTAL_TERMINALS()
        for _, key in ipairs(term_keys) do
          if terminals[key].cmd then
            vim.cmd("botright split") -- Create a horizontal split at the bottom
            terminals[key]:open() -- Open the terminal in the new split
            vim.cmd("wincmd j") -- Move to the new split
          end
        end
      end

      -- Set terminal keymaps
      function _G.set_terminal_keymaps()
        local term_opts = { buffer = 0, noremap = true }
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], term_opts)
        vim.keymap.set("t", "jk", [[<C-\><C-n>]], term_opts)
        vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-W>h]], term_opts)
        vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-W>j]], term_opts)
        vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-W>k]], term_opts)
        vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-W>l]], term_opts)
      end

      -- Apply keymaps when terminal opens
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          _G.set_terminal_keymaps()
        end,
      })

      -- LazyVim keybindings
      local keymap = vim.keymap.set

      -- General toggleterm keybindings
      keymap(
        "n",
        "<leader>t",
        "<cmd>ToggleTerm<cr>",
        { desc = "Toggle Default Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>th",
        "<cmd>ToggleTerm size=10 direction=horizontal<cr>",
        { desc = "Horizontal Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>tv",
        "<cmd>ToggleTerm size=80 direction=vertical<cr>",
        { desc = "Vertical Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>tf",
        "<cmd>ToggleTerm direction=float<cr>",
        { desc = "Float Terminal", noremap = true, silent = true }
      )

      -- Specific terminal toggles
      keymap(
        "n",
        "<leader>tp",
        "<cmd>lua _POWERSHELL_TOGGLE()<cr>",
        { desc = "PowerShell Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>tb",
        "<cmd>lua _GITBASH_TOGGLE()<cr>",
        { desc = "Git Bash Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>tc",
        "<cmd>lua _CMD_TOGGLE()<cr>",
        { desc = "Command Prompt Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>ty",
        "<cmd>lua _PYTHON_TOGGLE()<cr>",
        { desc = "Python REPL Terminal", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>tg",
        "<cmd>lua _LAZYGIT_TOGGLE()<cr>",
        { desc = "LazyGit Terminal", noremap = true, silent = true }
      )

      -- Cycle and multi-terminal keybindings
      keymap(
        "n",
        "<leader>tn",
        "<cmd>lua _CYCLE_HORIZONTAL_TERMINALS()<cr>",
        { desc = "Cycle Horizontal Terminals", noremap = true, silent = true }
      )
      keymap(
        "n",
        "<leader>ta",
        "<cmd>lua _OPEN_ALL_HORIZONTAL_TERMINALS()<cr>",
        { desc = "Open All Horizontal Terminals", noremap = true, silent = true }
      )

      -- Send lines to terminals
      keymap(
        "n",
        "<leader>tsl",
        ":ToggleTermSendCurrentLine<cr>",
        { desc = "Send Current Line to Terminal", noremap = true, silent = true }
      )
      keymap(
        "v",
        "<leader>tsv",
        ":ToggleTermSendVisualLines<cr>",
        { desc = "Send Visual Lines to Terminal", noremap = true, silent = true }
      )
      keymap(
        "v",
        "<leader>tss",
        ":ToggleTermSendVisualSelection<cr>",
        { desc = "Send Visual Selection to Terminal", noremap = true, silent = true }
      )
    end,
  },
}
