local M = {}

function M.toggle_angular_file()
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

return M
