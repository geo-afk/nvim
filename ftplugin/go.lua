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
  -- if vim.fn.filereadable 'Makefile' == 1 then
  -- 	cmd = 'make watch'
  -- else
  -- 	cmd = 'go run .'
  -- end

  cmd = 'go run .'

  -- Open a terminal in a horizontal split with 20% of the screen height
  vim.cmd('botright 15split | terminal ' .. cmd)

  -- Start the terminal in insert mode
  vim.cmd 'startinsert'
end, { desc = 'Run the current Go project in a terminal' })

--[[
  Run tests with gotestsum
  Examples:
    :GoTestRun        -> run all tests (./...)
    :GoTestRun %      -> run tests in current file
    :GoTestRun % -run MyFunc -> run a specific test in current file
]]
vim.api.nvim_create_user_command('GoTestRun', function(opts)
  local args = opts.args ~= '' and opts.args or './...'
  local cmd = string.format('gotestsum --format pkgname --hide-summary=skipped %s .', args)

  -- open a bottom terminal split
  vim.cmd 'botright split | resize 15'
  vim.cmd('terminal ' .. cmd)
  vim.cmd 'startinsert'
end, { nargs = '*', desc = 'Run Go tests with gotestsum' })

-- Safe load which-key
local ok, wk = pcall(require, 'which-key')
if not ok then
  vim.notify('which-key not found!', vim.log.levels.WARN)
  return
end

local icon = '⚙️'

-- Define Go-related keymaps
wk.add {
  {
    mode = { 'n' },
    { '<leader>g', icon = { icon = icon, hl = 'MiniIconsBrown' }, group = 'Golang' },
    { '<leader>gt', ':GoTests -all<CR>', desc = ' Generate tests for all functions', mode = 'n' },
    { '<leader>gm', ':GoModifyTags -add-tags json<CR>', desc = ' Add JSON tags', mode = 'n' },
    { '<leader>ga', ':GoTestRun<CR>', desc = ' Run all Go tests', mode = 'n' },
    {
      '<leader>gc',
      function()
        local testname = vim.fn.expand '<cword>'
        local file = vim.fn.expand '%'
        vim.cmd('GoTestRun ' .. file .. ' -run ' .. testname)
      end,
      desc = ' Run nearest Go test',
      mode = 'n',
    },
    {
      '<leader>gf',
      function()
        local file = vim.fn.expand '%'
        vim.cmd('GoTestRun ' .. file)
      end,
      desc = ' Run Go tests in current file',
      mode = 'n',
    },
    { '<leader>gr', ':GoModifyTags -remove-tags json<CR>', desc = ' Remove JSON tags', mode = 'n' },
    { '<leader>go', ':GoRun<CR>', desc = ' Run current Go File', mode = 'n' },
    { '<leader>ge', ':GoIfErr<CR>', desc = ' Insert if err snippet', mode = 'n' },
  },
}
