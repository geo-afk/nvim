local file_picker = require 'utils.file_selector'


-- to get coverage in golang html format: "go test -coverageprofile file.out main.go main_test.go; go tool -cover -html=c.out

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = false
vim.opt.textwidth = 120

-- Cache the floating terminal module
local float_term_mod = nil

local function get_float_term()
  if float_term_mod then
    return float_term_mod
  end

  local ok, mod = pcall(require, 'custom.float_term.term')
  if not ok then
    vim.notify('Failed to load floating terminal module: ' .. mod, vim.log.levels.ERROR)
    return nil
  end

  float_term_mod = mod
  return mod
end

-- Shared Go terminal styling
local go_term_config = {
  width_ratio = 0.8,
  height_ratio = 0.7,
  transparent = true,
  winblend = 15,
  colors = {
    title_bg = '#00ADD8', -- Go cyan
    title_fg = '#000000',
    border = '#00ADD8',
  },
}

-- Create a Go terminal (floating if available, fallback to split)
local function create_go_terminal(cmd, title, cwd)
  local ft = get_float_term()

  if not ft then
    vim.cmd 'botright 15split'
    vim.cmd('terminal ' .. cmd)
    vim.cmd 'startinsert'
    return
  end

  ft.setup(go_term_config)

  if cwd then
    local is_windows = vim.uv.os_uname().sysname:match 'Windows' ~= nil
    if is_windows then
      cmd = string.format('Push-Location -LiteralPath "%s"; %s; Pop-Location', cwd, cmd)
    else
      cmd = string.format('cd "%s" && %s', cwd, cmd)
    end
  end

  ft.create_terminal(cmd, { title = title })
end

-- Helper to run external command and reload buffer
local function run_tool_and_reload(cmd)
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('Command failed: ' .. result, vim.log.levels.ERROR)
  end
  vim.cmd 'edit!'
end

-- Helper to find corresponding test file or main file
local function get_test_file_pair(filepath)
  local is_test = filepath:match '_test%.go$'

  if is_test then
    -- If it's a test file, find the corresponding main file
    local main_file = filepath:gsub('_test%.go$', '.go')
    if vim.fn.filereadable(main_file) == 1 then
      return main_file, filepath
    else
      return nil, filepath
    end
  else
    -- If it's a main file, find the corresponding test file
    local test_file = filepath:gsub('%.go$', '_test.go')
    if vim.fn.filereadable(test_file) == 1 then
      return filepath, test_file
    else
      return filepath, nil
    end
  end
end

-- Helper to get relative path from cwd
local function get_relative_path(filepath)
  local cwd = vim.fn.getcwd()
  if filepath:sub(1, #cwd) == cwd then
    return filepath:sub(#cwd + 2) -- +2 to skip the trailing slash
  end
  return filepath
end

-- User commands
vim.api.nvim_create_user_command('GoTests', function(opts)
  local file = vim.fn.expand '%:p'
  local args = opts.args ~= '' and opts.args or '-all'
  local cmd = string.format('gotests -w %s %s', args, vim.fn.shellescape(file))
  run_tool_and_reload(cmd)
end, { nargs = '?', desc = 'Generate tests with gotests' })

vim.api.nvim_create_user_command('GoModifyTags', function(opts)
  local file = vim.fn.expand '%:p'
  local args = opts.args ~= '' and opts.args or '-all'
  local cmd = string.format('gomodifytags -file %s -w %s', vim.fn.shellescape(file), args)
  run_tool_and_reload(cmd)
end, { nargs = '?', desc = 'Modify struct tags with gomodifytags' })

vim.api.nvim_create_user_command('GoIfErr', function()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.fn.expand '%:p'
  local cmd = string.format('iferr -pos %d %s', line, vim.fn.shellescape(file))
  run_tool_and_reload(cmd)
end, { desc = 'Generate error handling with iferr' })

vim.api.nvim_create_user_command('GoRun', function()
  create_go_terminal('go run .', ' 󰐊 Go Run ')
end, { desc = 'Run the current Go project' })

vim.api.nvim_create_user_command('GoTestRun', function(opts)
  file_picker.select_file({
    prompt_title = 'Select Go file to test',
    cwd = vim.fn.getcwd(),
  }, function(selected_file)
    -- Handle cancellation
    if not selected_file then
      vim.notify('Test run cancelled', vim.log.levels.INFO)
      return
    end

    -- Validate it's a Go file
    if not selected_file:match '%.go$' then
      vim.notify('Please select a .go file', vim.log.levels.WARN)
      return
    end

    -- Get the main file and test file pair
    local main_file, test_file = get_test_file_pair(selected_file)

    -- Build the command
    local files_to_test = {}

    if main_file then
      table.insert(files_to_test, get_relative_path(main_file))
    end

    if test_file then
      table.insert(files_to_test, get_relative_path(test_file))
    end

    if #files_to_test == 0 then
      vim.notify('No valid Go files found', vim.log.levels.ERROR)
      return
    end

    -- Construct the gotestsum command
    local files_str = table.concat(files_to_test, ' ')
    local cmd = string.format('gotestsum --format pkgname --hide-summary=skipped %s', files_str)

    -- Show what we're testing
    if main_file and test_file then
      vim.notify(string.format('Running tests: %s + %s', vim.fn.fnamemodify(main_file, ':t'), vim.fn.fnamemodify(test_file, ':t')), vim.log.levels.INFO)
    elseif test_file then
      vim.notify(string.format('Running test file: %s (no main file found)', vim.fn.fnamemodify(test_file, ':t')), vim.log.levels.WARN)
    else
      vim.notify(string.format('Running file: %s (no test file found)', vim.fn.fnamemodify(main_file, ':t')), vim.log.levels.WARN)
    end

    -- Run the tests
    create_go_terminal(cmd, ' 󰤑 Go Tests ')
  end)
end, { nargs = '*', desc = 'Run Go tests with gotestsum' })

vim.api.nvim_create_user_command('GoTestRunCurrent', function()
  local current_file = vim.fn.expand '%:p'

  -- Validate it's a Go file
  if not current_file:match '%.go$' then
    vim.notify('Current file is not a .go file', vim.log.levels.WARN)
    return
  end

  -- Get the main file and test file pair
  local main_file, test_file = get_test_file_pair(current_file)

  -- Build the command
  local files_to_test = {}

  if main_file then
    table.insert(files_to_test, get_relative_path(main_file))
  end

  if test_file then
    table.insert(files_to_test, get_relative_path(test_file))
  end

  if #files_to_test == 0 then
    vim.notify('No valid Go files found', vim.log.levels.ERROR)
    return
  end

  -- Construct the gotestsum command
  local files_str = table.concat(files_to_test, ' ')
  local cmd = string.format('gotestsum --format pkgname --hide-summary=skipped %s', files_str)

  -- Show what we're testing
  if main_file and test_file then
    vim.notify(string.format('Running tests: %s + %s', vim.fn.fnamemodify(main_file, ':t'), vim.fn.fnamemodify(test_file, ':t')), vim.log.levels.INFO)
  elseif test_file then
    vim.notify(string.format('Running test file: %s (no main file found)', vim.fn.fnamemodify(test_file, ':t')), vim.log.levels.WARN)
  else
    vim.notify(string.format('Running file: %s (no test file found)', vim.fn.fnamemodify(main_file, ':t')), vim.log.levels.WARN)
  end

  -- Run the tests
  create_go_terminal(cmd, ' 󰤑 Go Tests ')
end, { desc = 'Run tests for current Go file' })

-- Which-key mappings (safe load)
local status, wk = pcall(require, 'which-key')
if not status then
  vim.notify('which-key not found!', vim.log.levels.WARN)
  return
end

wk.add {
  { '<leader>g', group = 'Go LSP', icon = '󰟓' },

  { '<leader>gt', ':GoTests -all<CR>', desc = 'Generate tests for all functions', icon = '󰙨' },
  { '<leader>gm', ':GoModifyTags -add-tags json<CR>', desc = 'Add JSON tags', icon = '󰓹' },
  { '<leader>gr', ':GoModifyTags -remove-tags json<CR>', desc = 'Remove JSON tags', icon = '󰓹' },

  { '<leader>ga', ':GoTestRun<CR>', desc = 'Run Go test (select file)', icon = '󰤑' },
  { '<leader>gc', ':GoTestRunCurrent<CR>', desc = 'Run tests for current file', icon = '󰤑' },
  { '<leader>go', ':GoRun<CR>', desc = 'Run current Go project', icon = '󰐊' },
  { '<leader>ge', ':GoIfErr<CR>', desc = 'Insert if err snippet', icon = '󰈸' },
}
