-- lua/plugins/nushell.lua
return {
  { "LhKipp/nvim-nu", ft = "nu", config = true },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      shell = "nu",
      size = 15,
      open_mapping = [[<c-\>]], -- Ctrl+\ to open terminal
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      direction = "horizontal", -- 'vertical', 'horizontal', 'tab', or 'float'
      close_on_exit = true,
      float_opts = {
        border = "curved", -- 'single', 'double', 'curved', 'shadow'
        winblend = 3,
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Terminal keymaps
      function _G.set_terminal_keymaps()
        opts = { buffer = 0 }
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
        vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
        vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
        vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
        vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
      end

      vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
    end,
  },
}
