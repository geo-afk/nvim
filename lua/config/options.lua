-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--

vim.opt.termguicolors = true

vim.opt.wildignore:append({ "*/node_modules/*" })

vim.o.scrolloff = 5 -- or even lower, like 3
