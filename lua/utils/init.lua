local M = {}

M.git_icons = {
  added = ' ',
  modified = ' ',
  removed = ' ',
}

M.diagnostic_icons = {
  Error = ' ',
  Warn = ' ',
  Info = ' ',
  Hint = '󰌵 ',
}

M.devicons_override = {
  default_icon = {
    icon = '󰈚',
    name = 'Default',
    color = '#E06C75',
  },
  toml = {
    icon = '',
    name = 'toml',
    color = '#61AFEF',
  },
  tsx = {
    icon = '',
    name = 'Tsx',
    color = '#20c2e3',
  },
  gleam = {
    icon = '',
    name = 'Gleam',
    color = '#FFAFF3',
  },
  py = {
    icon = '',
    color = '#519ABA',
    cterm_color = '214',
    name = 'Py',
  },
}

local function get_cwd()
  local function realpath(path)
    if path == '' or path == nil then
      return nil
    end
    return vim.loop.fs_realpath(path) or path
  end

  return realpath(vim.loop.cwd()) or ''
end

---@return fun():string
function M.pretty_dirpath()
  return function()
    local path = vim.fn.expand '%:p' --[[@as string]]

    if path == '' then
      return ''
    end
    local cwd = get_cwd()

    if path:find(cwd, 1, true) == 1 then
      path = path:sub(#cwd + 2)
    end

    local sep = package.config:sub(1, 1)
    local parts = vim.split(path, '[\\/]')
    table.remove(parts)
    if #parts > 3 then
      parts = { parts[1], '…', parts[#parts - 1], parts[#parts] }
    end

    return #parts > 0 and (table.concat(parts, sep)) or ''
  end
end

return M
