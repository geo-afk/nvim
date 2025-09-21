vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = false
vim.opt.textwidth = 120

--[[
  Generate tests for all functions in the current file: :GoTests -all
  Generate tests for exported functions: :GoTests -exported
  Generate tests for a specific function (using regex): :GoTests -only MyFunction
  Run :GoTests without arguments to generate tests for the function under the cursor (if gotests supports it).
]]

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

vim.api.nvim_create_user_command('GoIfErr', function(opts)
  local line = vim.api.nvim_win_get_cursor(0)[1] -- Get current line number
  local file = vim.fn.expand '%'
  local cmd = string.format('iferr -pos %d < %s', line, file)
  vim.fn.system(cmd)
  vim.cmd 'edit!' -- Reload the file
end, { desc = 'Generate error handling with iferr for current position' })

vim.api.nvim_create_user_command('GoRun', function()
  local cmd
  if vim.fn.filereadable 'Makefile' == 1 then
    cmd = 'make watch'
  else
    cmd = 'go run .'
  end

  -- Open a terminal in a horizontal split with 20% of the screen height
  vim.cmd('botright 20split | terminal ' .. cmd)

  -- Start the terminal in insert mode
  vim.cmd 'startinsert'
end, { desc = 'Run the current Go project in a terminal' })

vim.keymap.set('n', '<leader>gt', ':GoTests -all<CR>', { desc = 'Generate tests for all functions' })
vim.keymap.set('n', '<leader>gm', ':GoModifyTags -add-tags json<CR>', { desc = 'Add JSON tags' })
vim.keymap.set('n', '<leader>gr', ':GoModifyTags -remove-tags json<CR>', { desc = 'Remove JSON tags' })
vim.keymap.set('n', '<leader>go', ':GoRun<CR>', { desc = 'Run the current Go file' })
vim.keymap.set('n', '<leader>ge', ':GoIfErr<CR>', { desc = 'Insert if err snippet' })
