-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function augroup(name)
  return vim.api.nvim_create_augroup('lazyvim_' .. name, { clear = true })
end

vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'wrap_spell',
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

local lang_maps = {

  c = { build = 'gcc *.c -lm -g -o main', exec = './main' },
  cpp = {
    build = 'mkdir -p build && cd build && cmake .. && make',
    exec = 'cd build && ./main',
  },
  angular = { exec = 'ng serve' },
  go = { build = 'go build', exec = 'go run %' },
  java = { build = 'javac %', exec = 'java %:r' },
  javascript = { exec = 'bun %' },
  python = { exec = 'python %' },
  rust = { exec = 'cargo run' },
  sh = { exec = '%' },
  tex = { build = 'pdflatex -shell-escape %' },
  typescript = { exec = 'tsc % && node %:r.js' }, -- Fixed: compile then run
}

for lang, data in pairs(lang_maps) do
  -- Check for Makefile and properly close file handle
  local f = io.open('Makefile', 'r')
  if f then
    f:close() -- Properly close the file handle
    data.build = 'make build'
    data.exec = 'make exec'
  end

  -- Uncomment and fix build command if needed
  -- if data.build ~= nil then
  --   vim.api.nvim_create_autocmd("FileType", {
  --     pattern = lang,
  --     callback = function()
  --       vim.keymap.set("n", "<Leader>b", ":!" .. data.build .. "<CR>", { buffer = true })
  --     end,
  --   })
  -- end

  if data.exec ~= nil then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = lang,
      callback = function()
        -- Changed from "rr" to "<C-r>" (Ctrl+r) and fixed syntax
        vim.keymap.set('n', '<C-r>', ':split<CR>:terminal ' .. data.exec .. '<CR>', { buffer = true })
      end,
    })
  end
end

vim.api.nvim_create_autocmd('InsertEnter', { command = 'set norelativenumber', pattern = '*' })
vim.api.nvim_create_autocmd('InsertLeave', { command = 'set relativenumber', pattern = '*' })

-- vim.filetype.add({
--   extension = {
--     astro = "astro",
--     tpp = "cpp",
--     mdx = "markdown.mdx",
--   },
--   pattern = {
--     ["hyprland.conf"] = "hyprlang",
--   },
-- })
