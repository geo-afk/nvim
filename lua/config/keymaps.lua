-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>rn", function()
  return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "IncRename" })

local map = LazyVim.safe_keymap_set

-- floating terminal
map("n", "<leader>fT", function()
  Snacks.terminal()
end, { desc = "Terminal (cwd)" })
---
map("n", "<leader>ft", function()
  Snacks.terminal(nil, { cwd = LazyVim.root() })
end, { desc = "Terminal (Root Dir)" })
---
map("n", "<c-/>", function()
  Snacks.terminal(nil, { cwd = LazyVim.root() })
end, { desc = "Terminal (Root Dir)" })

---
map("n", "<c-_>", function()
  Snacks.terminal(nil, { cwd = LazyVim.root() })
end, { desc = "which_key_ignore" })

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
