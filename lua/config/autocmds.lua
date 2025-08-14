-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

--[[
  Generate tests for all functions in the current file: :GoTests -all
  Generate tests for exported functions: :GoTests -exported
  Generate tests for a specific function (using regex): :GoTests -only MyFunction
  Run :GoTests without arguments to generate tests for the function under the cursor (if gotests supports it).
]]

-- vim.keymap.set('n', '<leader>gt', ':GoTests -all<CR>', { desc = 'Generate tests for all functions' })
-- vim.keymap.set('n', '<leader>gm', ':GoModifyTags -add-tags json<CR>', { desc = 'Add JSON tags' })
-- vim.keymap.set('n', '<leader>gr', ':GoModifyTags -remove-tags json<CR>', { desc = 'Remove JSON tags' })

vim.api.nvim_create_user_command('GoTests', function(opts)
  local file = vim.fn.expand '%'
  local cmd = 'gotests -w'
  if opts.args ~= '' then
    cmd = cmd .. ' ' .. opts.args
  end
  cmd = cmd .. ' ' .. file
  vim.fn.system(cmd)
  vim.cmd 'edit!' -- Reload the file
end, { nargs = '?', desc = 'Generate tests with gotests' })

--[[
  Add JSON tags to a struct under the cursor: :GoModifyTags -add-tags json
  Remove JSON tags: :GoModifyTags -remove-tags json
  Add specific tags with options: :GoModifyTags -add-tags json -add-options json=omitempty
  Clear all tags: :GoModifyTags -clear-tags
]]

vim.api.nvim_create_user_command('GoModifyTags', function(opts)
  local file = vim.fn.expand '%'
  local cmd = string.format('gomodifytags -file %s -all -w', file)
  if opts.args ~= '' then
    cmd = cmd .. ' ' .. opts.args
  end
  vim.fn.system(cmd)
  vim.cmd 'edit!' -- Reload the file
end, { nargs = '?', desc = 'Modify struct tags with gomodifytags for entire file' })

-- vim.api.nvim_create_user_command('GoModifyTags', function(opts)
--   local file = vim.fn.expand '%'
--   local line = vim.api.nvim_win_get_cursor(0)[1] -- Get current line number
--   local cmd = string.format('gomodifytags -file %s -line %d -w', file, line)
--   if opts.args ~= '' then
--     cmd = cmd .. ' ' .. opts.args
--   end
--   vim.fn.system(cmd)
--   vim.cmd 'edit!' -- Reload the file
-- end, { nargs = '?', desc = 'Modify struct tags with gomodifytags' })

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
