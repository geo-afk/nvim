-- File: ~/.config/nvim/lua/plugins/my-file-manager.lua
-- LazyVim configuration for yazi.nvim plugin

---@type LazySpec
return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy", -- Load the plugin lazily
    dependencies = {
      "folke/snacks.nvim", -- Required dependency for yazi.nvim
    },
    keys = {
      -- Keybinding to open Yazi at the current file
      { "<leader>-", "<cmd>Yazi<cr>", desc = "Open Yazi at the current file", mode = { "n", "v" } },
      -- Keybinding to open Yazi in Neovim's working directory
      { "<leader>cw", "<cmd>Yazi cwd<cr>", desc = "Open Yazi in nvim's working directory" },
      -- Keybinding to resume the last Yazi session
      { "<c-up>", "<cmd>Yazi toggle<cr>", desc = "Resume the last Yazi session" },
      -- Optional: Keybinding to open Yazi at a specific directory (e.g., Neovim config)
      {
        "<leader>yn",
        function()
          require("yazi").yazi({}, "~/.config/nvim/lua/custom/")
        end,
        desc = "[Y]azi [n]vim directory",
      },
    },
    opts = {
      -- Replace netrw with Yazi
      open_for_directories = true,
      -- Keymappings for Yazi when it's open
      keymaps = {
        show_help = "<f1>",
        open_file_in_vertical_split = "<c-v>",
        open_file_in_horizontal_split = "<c-x>",
        open_file_in_tab = "<c-t>",
        grep_in_directory = "<c-s>", -- Requires telescope.nvim, fzf-lua.nvim, or snacks.picker
        replace_in_directory = "<c-g>", -- Requires grug-far.nvim
        cycle_open_buffers = "<tab>", -- Jump to open buffers in Neovim
        copy_relative_path_to_selected_files = "<c-y>", -- Requires realpath/grealpath
        send_to_quickfix_list = "<c-q>",
        change_working_directory = "<c-\\>",
      },
      -- Customize the floating window appearance
      yazi_floating_window_border = "rounded",
      -- Process events live for real-time updates
      future_features = {
        process_events_live = true,
      },
      -- Highlight buffers in the same directory as the hovered file
      highlight_hovered_buffers_in_same_directory = true,
      -- Integrations with other plugins
      integrations = {
        -- Use telescope for grep if available
        grep_in_directory = function(directory)
          if pcall(require, "telescope") then
            require("telescope.builtin").live_grep({ cwd = directory })
          end
        end,
        -- Use grug-far.nvim for search and replace if available
        replace_in_directory = function(directory)
          if pcall(require, "grug-far") then
            require("grug-far").open({ paths = { directory } })
          end
        end,
      },
    },
    -- Recommended initialization to disable netrw when using open_for_directories
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
  },
}
