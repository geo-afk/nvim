return {
  {
    "akinsho/toggleterm.nvim",
    version = "v2.*",
    event = "VeryLazy",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        end
      end,
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      on_open = function(term)
        -- Get the previous buffer name (the one before terminal opened)
        local prev_buf_path = vim.fn.bufname(vim.fn.bufnr("#"))
        local dir

        if prev_buf_path ~= "" and not prev_buf_path:match("^term://") then
          dir = vim.fn.fnamemodify(prev_buf_path, ":p:h")
        else
          dir = vim.fn.getcwd()
        end

        if dir and dir ~= "" then
          term:send("cd " .. vim.fn.fnameescape(dir) .. " ; clear", false)
        end
      end,
      close_on_exit = true,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      local Terminal = require("toggleterm.terminal").Terminal

      -- Create multiple terminal instances for horizontal splitting
      local terminals = {}
      for i = 1, 4 do
        terminals[i] = Terminal:new({
          direction = "horizontal",
          hidden = true,
          display_name = "Terminal " .. i,
          on_open = function(term)
            -- Get the previous buffer name (the one before terminal opened)
            local prev_buf_path = vim.fn.bufname(vim.fn.bufnr("#"))
            local dir

            if prev_buf_path ~= "" and not prev_buf_path:match("^term://") then
              dir = vim.fn.fnamemodify(prev_buf_path, ":p:h")
            else
              dir = vim.fn.getcwd()
            end

            if dir and dir ~= "" then
              term:send("cd " .. vim.fn.fnameescape(dir) .. " ; clear", false)
            end
          end,
        })
      end

      -- Functions to toggle specific terminals
      for i = 1, 4 do
        _G["_TERMINAL_" .. i .. "_TOGGLE"] = function()
          terminals[i]:toggle()
        end
      end

      -- Terminal navigation keymaps
      function _G.set_terminal_keymaps()
        local term_opts = { buffer = 0, noremap = true }
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], term_opts)
        vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-W>h]], term_opts)
        vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-W>j]], term_opts)
        vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-W>k]], term_opts)
        vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-W>l]], term_opts)
      end

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          _G.set_terminal_keymaps()
        end,
      })

      -- Default terminal toggle
      local wk = require("which-key")
      wk.add({
        { "<leader>t", group = "Terminal", icon = "" },
        { "<leader>t1", "<cmd>lua _TERMINAL_1_TOGGLE()<cr>", desc = "Terminal 1" },
        { "<leader>t2", "<cmd>lua _TERMINAL_2_TOGGLE()<cr>", desc = "Terminal 2" },
        { "<leader>t3", "<cmd>lua _TERMINAL_3_TOGGLE()<cr>", desc = "Terminal 3" },
        { "<leader>t4", "<cmd>lua _TERMINAL_4_TOGGLE()<cr>", desc = "Terminal 4" },
        { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Default Terminal" },
      })
    end,
  },
}
