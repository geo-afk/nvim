-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local opts = { noremap = true, silent = true }

vim.o.updatetime = 250
vim.cmd([[
  autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- Select All
vim.keymap.set("n", "<C-a>", "gg<S-v>G")

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

-- ~/.config/nvim/lua/config/keymaps.lua
local Terminal = require("toggleterm.terminal").Terminal

--
--
--
--
--
--
-- Create specific terminals for Angular commands
local ng_terminal = Terminal:new({
  cmd = "ng ",
  direction = "horizontal",
  close_on_exit = false,
})

local ng_serve_terminal = Terminal:new({
  cmd = "ng serve",
  direction = "horizontal",
  close_on_exit = false,
})

local ng_test_terminal = Terminal:new({
  cmd = "ng test",
  direction = "horizontal",
  close_on_exit = false,
})

-- Keymaps for Angular ClI tools
vim.keymap.set("n", "<leader>ng", function()
  ng_terminal:toggle()
end, { desc = "Angular CLI" })

vim.keymap.set("n", "<leader>ns", function()
  ng_serve_terminal:toggle()
end, { desc = "Angular Serve" })

vim.keymap.set("n", "<leader>nt", function()
  ng_test_terminal:toggle()
end, { desc = "Angular Test" })

--
--
--
--
-- Enhanced version that handles indentation better
vim.keymap.set("n", "<A-Up>", function()
  if vim.fn.line(".") == 1 then
    return
  end
  vim.cmd("m .-2")
  vim.cmd("normal! ==")
end, { desc = "Move line up", silent = true })

vim.keymap.set("n", "<A-Down>", function()
  if vim.fn.line(".") == vim.fn.line("$") then
    return
  end
  vim.cmd("m .+1")
  vim.cmd("normal! ==")
end, { desc = "Move line down", silent = true })

vim.keymap.set("v", "<A-Up>", function()
  vim.cmd("'<,'>m '<-2")
  vim.cmd("normal! gv=gv")
end, { desc = "Move selection up", silent = true })

vim.keymap.set("v", "<A-Down>", function()
  vim.cmd("'<,'>m '>+1")
  vim.cmd("normal! gv=gv")
end, { desc = "Move selection down", silent = true })
