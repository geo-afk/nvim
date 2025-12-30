vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = false
vim.opt.textwidth = 120

-- Lazily load the floating terminal module
local float_term = nil
local function get_float_term()
  if not float_term then
    local ok, mod = pcall(require, 'custom.float_term.term')
    if not ok then
      vim.notify('Failed to load floating terminal module: ' .. mod, vim.log.levels.ERROR)
      return nil
    end
    float_term = mod
  end
  return float_term
end

--[[ GoTests command ]]
vim.api.nvim_create_user_command('GoTests', function(opts)
  local file = vim.fn.expand '%'
  local cmd = 'gotests -w'
  if opts.args ~= '' then
    cmd = cmd .. ' ' .. opts.args
  end
  cmd = cmd .. ' ' .. file
  vim.fn.system(cmd)
  vim.cmd 'edit!'
end, { nargs = '?', desc = 'Generate tests with gotests' })

--[[ GoModifyTags command ]]
vim.api.nvim_create_user_command('GoModifyTags', function(opts)
  local file = vim.fn.expand '%'
  local cmd = string.format('gomodifytags -file %s -all -w', file)
  if opts.args ~= '' then
    cmd = cmd .. ' ' .. opts.args
  end
  vim.fn.system(cmd)
  vim.cmd 'edit!'
end, { nargs = '?', desc = 'Modify struct tags with gomodifytags for entire file' })

--[[ GoIfErr command ]]
vim.api.nvim_create_user_command('GoIfErr', function(opts)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.fn.expand '%'
  local cmd = string.format('iferr -pos %d < %s', line, file)
  vim.fn.system(cmd)
  vim.cmd 'edit!'
end, { desc = 'Generate error handling with iferr for current position' })

--[[ GoRun – now uses floating terminal ]]
vim.api.nvim_create_user_command('GoRun', function()
  local ft = get_float_term()
  if ft ~= nil then
    ft.setup { width_ratio = 0.6, height_ratio = 0.6 }
  end
  if not ft then
    vim.cmd 'botright 15split | terminal go run .'
    vim.cmd 'startinsert'
    return
  end
  ft.create_terminal('go run .', { title = ' Go Run ' })
end, { desc = 'Run the current Go project in a floating terminal' })

--[[ GoTestRun – now uses floating terminal ]]
vim.api.nvim_create_user_command('GoTestRun', function(opts)
  local args = opts.args ~= '' and opts.args or './...'
  local cmd = string.format('gotestsum --format pkgname --hide-summary=skipped %s', args)

  local ft = get_float_term()
  if not ft then
    vim.cmd 'botright split | resize 15'
    vim.cmd('terminal ' .. cmd)
    vim.cmd 'startinsert'
    return
  end

  ft.create_terminal(cmd, { title = ' Go Tests ' })
end, { nargs = '*', desc = 'Run Go tests with gotestsum in a floating terminal' })

-- Safe load which-key
local ok, wk = pcall(require, 'which-key')
if not ok then
  vim.notify('which-key not found!', vim.log.levels.WARN)
  return
end

-- Define Go-related keymaps (descriptions updated where needed)
wk.add {
  {
    mode = { 'n' },
    { '<leader>g', group = 'Go LSP', icon = '󰟓' }, -- Go icon
    { '<leader>gt', ':GoTests -all<CR>', desc = 'Generate tests for all functions', icon = '󰙨' }, -- generate icon
    { '<leader>gm', ':GoModifyTags -add-tags json<CR>', desc = 'Add JSON tags', icon = '󰓹' }, -- tag add icon
    { '<leader>ga', ':GoTestRun<CR>', desc = 'Run all Go tests', icon = '󰤑' }, -- test icon
    {
      '<leader>gc',
      function()
        local testname = vim.fn.expand '<cword>'
        local file = vim.fn.expand '%'
        vim.cmd('GoTestRun ' .. file .. ' -run ' .. testname)
      end,
      desc = 'Run nearest Go test',
      icon = '󰆧', -- target/focus icon
    },
    {
      '<leader>gf',
      function()
        local file = vim.fn.expand '%'
        vim.cmd('GoTestRun ' .. file)
      end,
      desc = 'Run Go tests in current file',
      icon = '󰈔', -- file test icon
    },
    { '<leader>gr', ':GoModifyTags -remove-tags json<CR>', desc = 'Remove JSON tags', icon = '󰓹' }, -- tag remove icon
    { '<leader>go', ':GoRun<CR>', desc = 'Run current Go project', icon = '󰐊' }, -- play/run icon
    { '<leader>ge', ':GoIfErr<CR>', desc = 'Insert if err snippet', icon = '󰈸' }, -- code snippet icon
  },
}
