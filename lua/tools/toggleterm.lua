-- ~/.config/nvim/lua/plugins/terminal.lua
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = 20,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      direction = "horizontal", -- 'vertical' | 'horizontal' | 'tab' | 'float'
      close_on_exit = true,
      shell = "nu", -- Change this line to use NuShell
      -- OR use full path if needed: shell = "/usr/bin/nu"
    },
  },
  {
    "folke/edgy.nvim",
    opts = {
      bottom = {
        {
          ft = "toggleterm",
          size = { height = 0.21 },
          filter = function(buf, win)
            return vim.api.nvim_win_get_config(win).relative == ""
          end,
        },
      },
      left = {
        {
          title = "Diagnostics",
          ft = "Trouble",
          size = { width = 0.25 }, -- adjust size as needed
        },
      },
    },
  },
}
