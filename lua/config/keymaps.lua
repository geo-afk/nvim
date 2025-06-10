-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local opts = { noremap = true, silent = true }

-- save file
vim.keymap.set("i", "<C-s>", "<cmd> w <CR>", opts)

-- quite a file
vim.keymap.set("n", "<C-q>", "<cmd> q <CR>", opts)

-- delete single character without copying it to the register
vim.keymap.set("n", "x", '"_x', opts)

-- Navigate between splits
vim.keymap.set("n", "[]", "<C-w>v", opts)
vim.keymap.set("n", "]\\", "<C-w>s", opts)
vim.keymap.set("n", "\\]", "<C-w>/", opts)
vim.keymap.set("n", "]xs", ":close<CR>", opts)
