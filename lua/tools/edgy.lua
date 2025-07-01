-- ~/.config/nvim/lua/plugins/terminal.lua
return {
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
}
