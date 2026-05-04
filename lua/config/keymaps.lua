-- =============================================================================
--  config/keymaps.lua  ·  Centralized General Key Mappings
-- =============================================================================

local map = vim.keymap.set
local noremap_s = { noremap = true, silent = true }

-- ── 1. General & Editor Navigation ──────────────────────────────────────────
map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (wrap-aware)" })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (wrap-aware)" })

-- Clear search highlight
map("n", "<Esc>", function()
  vim.cmd("nohlsearch")
end, { silent = true, desc = "Clear search highlights" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", noremap_s)
map("n", "<C-j>", "<C-w>j", noremap_s)
map("n", "<C-k>", "<C-w>k", noremap_s)
map("n", "<C-l>", "<C-w>l", noremap_s)

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<CR>", noremap_s)
map("n", "<C-Down>", "<cmd>resize -2<CR>", noremap_s)
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", noremap_s)
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", noremap_s)

-- Centered scrolling
map("n", "n", "nzz", noremap_s)
map("n", "<C-d>", "<C-d>zz", noremap_s)
map("n", "<C-u>", "<C-u>zz", noremap_s)

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Select All
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Save file
map({ "i", "n" }, "<C-s>", "<cmd>w<CR>", noremap_s)
map("n", "<leader>ww", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>wa", "<cmd>wall ++p<CR>", { desc = "Save all (auto-parents)" })

-- Paste without replacing clipboard
map("v", "<leader>P", '"_dP', vim.tbl_extend("force", noremap_s, { desc = "Paste without yanking" }))

-- ── 2. Terminal Mode ────────────────────────────────────────────────────────
-- Terminal mode mappings
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
map("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide Terminal" })
