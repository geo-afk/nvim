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

  print(angular_file)
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
