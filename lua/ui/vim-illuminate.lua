-- ~/.config/nvim/lua/plugins/vim-illuminate.lua
return {
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" }, -- Load plugin after opening a buffer
    opts = {
      -- Providers used to get references in the buffer, ordered by priority
      providers = {
        "lsp",
        "treesitter",
        "regex",
      },
      -- Delay in milliseconds before highlighting
      delay = 100,
      -- Filetypes to exclude from illumination
      filetypes_denylist = {
        "dirvish",
        "fugitive",
        "alpha",
        "NvimTree",
        "lazy",
        "mason",
        "help",
        "qf",
      },
      -- Whether to highlight under the cursor
      under_cursor = true,
      -- Minimum number of matches required to highlight
      min_count_to_highlight = 1,
      -- Case insensitive regex matching
      case_insensitive_regex = false,
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
      -- Optional: Define custom highlight groups
      vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "CursorLine" })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "CursorLine" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "CursorLine" })
      -- Optional: Keymaps for navigation
      vim.keymap.set("n", "<a-n>", require("illuminate").goto_next_reference, { desc = "Go to next reference" })
      vim.keymap.set("n", "<a-p>", require("illuminate").goto_prev_reference, { desc = "Go to previous reference" })
    end,
  },
}
