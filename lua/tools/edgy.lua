-- ~/.config/nvim/lua/plugins/terminal.lua
return {
  "folke/edgy.nvim",
  opts = {
    bottom = {
      {
        title = "Terminal",
        ft = "terminal",
        -- Dynamically size
        size = function()
          return math.floor(vim.o.lines * 0.3)
        end,
        filter = function(_, win)
          return vim.api.nvim_win_get_config(win).relative == ""
        end,
        -- filter = function(buf)
        --   return vim.bo[buf].buftype == "terminal"
        -- end,
      },
      {
        ft = "snacks_terminal",
        size = { height = 0.3 },
        title = "%{b:snacks_terminal.id}: %{b:term_title}",
        filter = function(_, win)
          return vim.w[win].snacks_win
            and vim.w[win].snacks_win.position == "bottom"
            and vim.w[win].snacks_win.relative == "editor"
            and not vim.w[win].trouble_preview
        end,
      },
      {
        ft = "help",
        size = { height = 20 },
        filter = function(buf)
          return vim.bo[buf].buftype == "help"
        end,
      },
      {
        ft = "qf",
        title = "QUICKFIX",
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
