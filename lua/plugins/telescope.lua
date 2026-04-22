-- =============================================================================
--  plugins/telescope.lua  ·  telescope.nvim + fzf-native
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  {
    src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim",
    build = (function()
      return vim.fn.executable("make") == 1 and "make" or nil
    end)(),
  },
  { src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" },
})

local ok, telescope = pcall(require, "telescope")
if not ok then
  return
end

telescope.setup({
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown(),
    },
  },
})

local map = vim.keymap.set
map("n", "<leader><leader>", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Buffer search" })
map("n", "<leader>sf", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>sw", "<cmd>Telescope grep_string<cr>", { desc = "Grep current word" })
map("n", "<leader>sd", "<cmd>Telescope diagnostics<cr>", { desc = "Search diagnostics" })
map("n", "<leader>sk", "<cmd>Telescope keymaps<cr>", { desc = "Search keymaps" })
map("n", "<leader>sh", "<cmd>Telescope help_tags<cr>", { desc = "Search help tags" })
map("n", "<leader>ss", "<cmd>Telescope builtin<cr>", { desc = "Search pickers" })
map("n", "<leader>sr", "<cmd>Telescope resume<cr>", { desc = "Resume search" })
map("n", "<leader>s.", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>si", function()
  require("telescope.builtin").find_files({ hidden = true, no_ignore = true })
end, { desc = "Search hidden files" })
map("n", "<leader>sn", function()
  require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search Neovim config" })
map("n", "<leader>s/", function()
  require("telescope.builtin").live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
end, { desc = "Grep open files" })

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "ui-select")
