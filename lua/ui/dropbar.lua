return {
  "Bekaboo/dropbar.nvim",
  dependencies = {
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  config = function()
    vim.o.mousemoveevent = true

    require("dropbar").setup({
      bar = {
        -- Moved from `general`
        enable = function(buf, win)
          return not vim.api.nvim_win_get_config(win).zindex
            and vim.bo[buf].buftype == ""
            and vim.api.nvim_buf_get_name(buf) ~= ""
            and not vim.wo[win].diff
        end,

        -- Customize the bar's appearance
        padding = { left = 1, right = 1, bottom = 2 },
        win_configs = {
          border = "none",
          row = 1,
          col = 0,
          winblend = 0,
        },
      },
      menu = {
        win_configs = {
          border = "rounded",
          col = function(menu)
            return menu.parent_menu and menu.parent_menu.win_configs.col or 0
          end,
          row = function(menu)
            return menu.parent_menu and menu.parent_menu.win_configs.row + 1 or 2
          end,
          winblend = 0,
        },
      },
    })

    local dropbar_api = require("dropbar.api")
    vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
    vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
    vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })

    vim.api.nvim_set_hl(0, "DropBarMenuNormal", { bg = "NONE", fg = "#cdd6f4" })
    vim.api.nvim_set_hl(0, "DropBarMenuNormalFloat", { bg = "NONE", fg = "#cdd6f4" })
    vim.api.nvim_set_hl(0, "DropBarMenuBorder", { bg = "NONE", fg = "#585b70" })
    vim.api.nvim_set_hl(0, "DropBarIconUIIndicator", { bg = "NONE", fg = "#cba6f7" })
    vim.api.nvim_set_hl(0, "DropBarKind", { bg = "NONE", fg = "#94e2d5" })
  end,
}
