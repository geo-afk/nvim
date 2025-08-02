-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- views can only be fully collapsed with the global statusline
vim.opt.laststatus = 3
-- Default splitting will cause your main splits to jump when opening an edgebar.
-- To prevent this, set `splitkeep` to either `screen` or `topline`.
vim.opt.splitkeep = "screen"
vim.opt.termguicolors = true
vim.opt.wildignore:append({ "*/node_modules/*" })
vim.o.scrolloff = 5 -- or even lower, like 3
vim.g.have_nerd_font = false

-- Nushell configuration
vim.opt.shell = "nu"
vim.opt.shellquote = ""
vim.opt.shellxquote = ""
