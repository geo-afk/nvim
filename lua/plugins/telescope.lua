-- =============================================================================
--  plugins/telescope.lua  ·  telescope.nvim + fzf-native
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  {
    src   = "https://github.com/nvim-telescope/telescope-fzf-native.nvim",
    build = (function()
      return vim.fn.executable("make") == 1 and "make" or nil
    end)(),
  },
  { src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" },
})

local ok, telescope = pcall(require, "telescope")
if not ok then return end

telescope.setup({
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown(),
    },
  },
})

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "ui-select")

local builtin = require("telescope.builtin")
local map     = vim.keymap.set

map("n", "<leader>sh", builtin.help_tags,   { desc = "Search Help" })
map("n", "<leader>sk", builtin.keymaps,     { desc = "Search Keymaps" })
map("n", "<leader>sf", builtin.find_files,  { desc = "Search Files" })
map("n", "<leader>ss", builtin.builtin,     { desc = "Search Select Telescope" })
map("n", "<leader>sw", builtin.grep_string, { desc = "Search current Word" })
map("n", "<leader>sg", builtin.live_grep,   { desc = "Search by Grep" })
map("n", "<leader>sd", builtin.diagnostics, { desc = "Search Diagnostics" })
map("n", "<leader>sr", builtin.resume,      { desc = "Search Resume" })
map("n", "<leader>s.", builtin.oldfiles,    { desc = 'Search Recent Files ("." repeat)' })
map("n", "<leader>/",  builtin.buffers,     { desc = "Find existing buffers" })

map("n", "<leader>si", function()
  builtin.find_files({ hidden = true, no_ignore = true })
end, { desc = "Search Hidden Files" })

map("n", "<leader>sn", function()
  builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search Neovim config files" })

map("n", "<leader>s/", function()
  builtin.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
end, { desc = "Search / in Open Files" })

map("n", "<leader><leader>", function()
  builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend  = 10,
    previewer = false,
  }))
end, { desc = "Fuzzily search in current buffer" })
