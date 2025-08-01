-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = LazyVim.safe_keymap_set

map("n", "<leader>rn", function()
  return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "IncRename" })

-- map("n", "<leader>xs", "<cmd>.lua<CR>", { desc = "Execute the current line" })

---
map("n", "<c-/>", function()
  -- Snacks.terminal(nil, { cwd = vim.fn.expand("%:p:h") })
  local root = vim.fs.root(0, { ".git", "lua", "Makefile", "package.json" }) or vim.fn.getcwd()
  vim.cmd("terminal cd " .. root .. "; nu")
end, { desc = "Terminal (Current Dir)" })

local opts = { noremap = true, silent = true }

vim.o.updatetime = 250
vim.cmd([[
  autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- Select All
map("n", "<C-a>", "gg<S-v>G")

-- save file
map("i", "<C-s>", "<cmd> w <CR>", opts)

-- quite a file
map("n", "<C-q>", "<cmd> q <CR>", opts)

-- delete single character without copying it to the register
map("n", "x", '"_x', opts)
--
-- Enhanced version that handles indentation better
map("n", "<A-Up>", function()
  if vim.fn.line(".") == 1 then
    return
  end
  vim.cmd("m .-2")
  vim.cmd("normal! ==")
end, { desc = "Move line up", silent = true })

map("n", "<A-Down>", function()
  if vim.fn.line(".") == vim.fn.line("$") then
    return
  end
  vim.cmd("m .+1")
  vim.cmd("normal! ==")
end, { desc = "Move line down", silent = true })

map("v", "<A-Up>", function()
  vim.cmd("'<,'>m '<-2")
  vim.cmd("normal! gv=gv")
end, { desc = "Move selection up", silent = true })

map("v", "<A-Down>", function()
  vim.cmd("'<,'>m '>+1")
  vim.cmd("normal! gv=gv")
end, { desc = "Move selection down", silent = true })

--#----------------------------------#
--
--#        Live Server          #---
--#----------------------------------#

map("n", "<leader>U", "<cmd>LiveServerStart<CR>", {
  noremap = true,
  silent = true,
  desc = "Start Live Server",
})
