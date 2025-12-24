function _G.userCommandCompletion(lead, line, _)
  local values = {}
  for value in line:gmatch '%S+' do
    table.insert(values, value)
  end

  if #values > 1 then
    return {}
  end

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

  local matches = {}
  for _, command in ipairs(commands) do
    if command:find(lead) then
      table.insert(matches, command)
    end
  end

  return matches
end

local function is_in_angular_project()
  local angular_file = vim.fn.findfile('angular.json', vim.fn.getcwd() .. ';')
  return angular_file ~= ''
end

local group = vim.api.nvim_create_augroup('Angular', {})
if is_in_angular_project() then
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = { '*ts', '*html', '*css' },
    callback = function()
      vim.api.nvim_create_user_command('Ng', function(args)
        local cmd = 'ng generate ' .. args.args
        vim.cmd('!' .. cmd)
      end, {
        nargs = '*',
        complete = 'customlist,v:lua.userCommandCompletion',
        bang = true,
      })
    end,
  })
end

function _G.toggle_angular_file()
  local current_file = vim.fn.expand '%:p'
  local extension = vim.fn.expand '%:e'
  local base_name = vim.fn.expand '%:r'
  local target_file

  if extension == 'ts' then
    -- Check if current file is a spec file
    if string.match(base_name, '%.spec$') then
      -- Remove .spec from the end to get the component file
      target_file = string.gsub(base_name, '%.spec$', '') .. '.ts'
    else
      -- Regular .ts file, toggle to .html
      target_file = base_name .. '.html'
    end
  elseif extension == 'html' then
    target_file = base_name .. '.ts'
  else
    print 'Not an Angular .ts or .html file'
    return
  end

  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. target_file)
  else
    print('Target file ' .. target_file .. ' does not exist')
  end
end
