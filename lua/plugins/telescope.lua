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

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "ui-select")
