-- Plugin configuration for dropbar.nvim in LazyVim with transparent background and padding

return {
  {
    "Bekaboo/dropbar.nvim",
    -- Optional dependency for fuzzy search support
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      -- Enable mouse movement events for hover functionality
      vim.o.mousemoveevent = true

      -- Set up dropbar with custom options
      require("dropbar").setup({
        general = {
          -- Ensure dropbar attaches to buffers
          enable = function(buf, win)
            return not vim.api.nvim_win_get_config(win).zindex
              and vim.bo[buf].buftype == ""
              and vim.api.nvim_buf_get_name(buf) ~= ""
              and not vim.wo[win].diff
          end,
        },
        bar = {
          -- Customize the bar's appearance
          padding = { left = 1, right = 1 },
          -- Configure the dropbar window position to add padding above
          win_configs = {
            border = "none", -- Clean look, no border
            row = 1, -- Shift dropbar down by 1 row to create padding above
            col = 0,
            winblend = 0, -- Maintain transparency
          },
        },
        menu = {
          -- Configure the dropdown menu window
          win_configs = {
            border = "rounded", -- Optional: rounded borders for aesthetics
            col = function(menu)
              return menu.parent_menu and menu.parent_menu.win_configs.col or 0
            end,
            row = function(menu)
              return menu.parent_menu and menu.parent_menu.win_configs.row + 1 or 2 -- Adjust menu row to align with bar
            end,
            -- Set transparent background for the menu
            winblend = 0,
          },
        },
      })

      -- Define keybindings for dropbar interactions
      local dropbar_api = require("dropbar.api")
      vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
      vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
      vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })

      -- Set transparent background for dropbar and menu
      vim.api.nvim_set_hl(0, "DropBarMenuNormal", { bg = "NONE", fg = "#cdd6f4" }) -- Catppuccin Mocha text color
      vim.api.nvim_set_hl(0, "DropBarMenuNormalFloat", { bg = "NONE", fg = "#cdd6f4" })
      vim.api.nvim_set_hl(0, "DropBarMenuBorder", { bg = "NONE", fg = "#585b70" }) -- Subtle border color
      vim.api.nvim_set_hl(0, "DropBarIconUIIndicator", { bg = "NONE", fg = "#cba6f7" }) -- Icon color
      vim.api.nvim_set_hl(0, "DropBarKind", { bg = "NONE", fg = "#94e2d5" }) -- Kind symbols color
    end,
  },
  {
    -- Optional: Configure global transparency for Neovim UI
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha", -- Use a theme that supports transparency
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      transparent_background = true,
      integrations = {
        dropbar = { enabled = true, color_mode = true },
        telescope = true,
        native_lsp = { enabled = true },
      },
    },
  },
  {
    -- Apply global transparency settings
    "xiyaowong/transparent.nvim",
    config = function()
      require("transparent").setup({
        groups = {
          "Normal",
          "NormalNC",
          "NonText",
          "SignColumn",
          "StatusLine",
          "StatusLineNC",
          "VertSplit",
          "TabLine",
          "TabLineFill",
          "TabLineSel",
          "Pmenu",
          "PmenuSel",
          "FloatBorder",
          "NormalFloat",
        },
        extra_groups = {
          "DropBarMenuNormal",
          "DropBarMenuNormalFloat",
          "DropBarMenuBorder",
          "DropBarIconUIIndicator",
          "DropBarKind",
        },
        exclude_groups = {},
      })
    end,
  },
}
