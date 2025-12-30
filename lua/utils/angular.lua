local utils = require 'utils'

-- ============================================================================
-- Command Completion
-- ============================================================================

--- Completion function for Angular CLI generate commands
--- @param lead string The leading portion of the argument being completed
--- @param line string The entire command line
--- @param _ any Unused cursor position parameter
--- @return table List of completion matches
function _G.userCommandCompletion(lead, line, _)
  -- Parse existing arguments
  local values = {}
  for value in line:gmatch '%S+' do
    table.insert(values, value)
  end

  -- Only provide completions for the first argument
  if #values > 1 then
    return {}
  end

  -- Available Angular CLI generate commands
  local commands = {
    'service',
    'component',
    'directive',
    'pipe',
    'module',
    'class',
    'guard',
    'interface',
    'enum',
    'lib',
  }

  -- Filter commands based on input
  local matches = {}
  for _, command in ipairs(commands) do
    if command:find(lead, 1, true) then
      table.insert(matches, command)
    end
  end

  return matches
end

-- ============================================================================
-- Angular CLI Command Setup
-- ============================================================================

--- Set up Angular CLI command if in an Angular project
local function setup_ng_command()
  if not utils.is_angular_project() then
    return
  end

  local group = vim.api.nvim_create_augroup('Angular', { clear = true })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = { '*.ts', '*.html', '*.css', '*.scss' },
    callback = function()
      -- Create :Ng command for Angular CLI generate
      vim.api.nvim_create_user_command('Ng', function(args)
        local cmd = 'ng generate ' .. args.args
        vim.cmd('!' .. cmd)
      end, {
        nargs = '*',
        complete = 'customlist,v:lua.userCommandCompletion',
        bang = true,
        desc = 'Execute Angular CLI generate command',
      })
    end,
  })
end

-- ============================================================================
-- File Navigation
-- ============================================================================

--- Toggle between related Angular files (TypeScript ↔ HTML, TypeScript ↔ Spec)
--- Handles three cases:
--- 1. .spec.ts → .ts (component/service file)
--- 2. .ts → .html (template file)
--- 3. .html → .ts (component file)
function _G.toggle_angular_file()
  local current_file = vim.fn.expand '%:p'
  local extension = vim.fn.expand '%:e'
  local base_name = vim.fn.expand '%:r'
  local target_file

  if extension == 'ts' then
    -- Check if current file is a spec file
    if string.match(base_name, '%.spec$') then
      -- Remove .spec from the end to get the component/service file
      target_file = string.gsub(base_name, '%.spec$', '') .. '.ts'
    else
      -- Regular .ts file, toggle to .html template
      target_file = base_name .. '.html'
    end
  elseif extension == 'html' then
    -- HTML template, toggle back to .ts component
    target_file = base_name .. '.ts'
  else
    vim.notify('Not an Angular .ts or .html file', vim.log.levels.WARN)
    return
  end

  -- Open the target file if it exists
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. target_file)
  else
    vim.notify('Target file ' .. target_file .. ' does not exist', vim.log.levels.WARN)
  end
end

-- ============================================================================
-- Initialization
-- ============================================================================

-- Set up Angular commands on load
setup_ng_command()

-- Example: <leader>at for "angular toggle"
-- vim.keymap.set('n', '<leader>at', _G.toggle_angular_file, { desc = 'Toggle Angular files' })
