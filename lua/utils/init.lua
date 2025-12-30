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



-- ============================================================================
-- Path Utilities
-- ============================================================================

--- Join path segments into a single path
--- @param ... string Path segments to join
--- @return string The joined path
local function join_path(...)
  return table.concat({ ... }, '/')
end

--- Get the Mason package installation path
--- Tries mason-registry first (preferred), then falls back to direct path lookup
--- @param pkg_name string The name of the Mason package
--- @param rel? string Optional relative path to append
--- @return string|nil The normalized package path, or nil if not found
function M.get_mason_pkg_path(pkg_name, rel)
  rel = rel or ''

  -- Try mason-registry first (preferred method)
  local ok, registry = pcall(require, 'mason-registry')
  if ok and registry then
    local success, pkg = pcall(registry.get_package, pkg_name)
    if success and pkg and pkg:is_installed() then
      local install_path = vim.fn.stdpath 'data' .. '/mason/packages/' .. pkg_name
      local final = install_path .. rel

      if vim.loop.fs_stat(final) then
        return vim.fs.normalize(final)
      end
      return vim.fs.normalize(install_path)
    end
  end

  -- Fallback to default mason packages location
  local data_dir = vim.fn.stdpath 'data'
  local candidate = join_path(data_dir, 'mason', 'packages', pkg_name) .. rel

  if vim.loop.fs_stat(candidate) then
    return vim.fs.normalize(candidate)
  end

  -- Some mason packages put node modules under the package dir
  local alt = join_path(data_dir, 'mason', 'packages', pkg_name, 'node_modules') .. rel

  if vim.loop.fs_stat(alt) then
    return vim.fs.normalize(alt)
  end

  return nil
end

-- ============================================================================
-- Angular Project Utilities
-- ============================================================================

--- Check if current directory is within an Angular project
--- @return boolean True if angular.json exists in current or parent directories
function M.is_angular_project()
  local angular_file = vim.fn.findfile('angular.json', vim.fn.getcwd() .. ';')
  return angular_file ~= ''
end

--- Find the Angular project root directory
--- @return string|nil The project root path, or nil if not found
function M.find_angular_root()
  local angular_file = vim.fn.findfile('angular.json', vim.fn.getcwd() .. ';')

  if angular_file == '' then
    return nil
  end

  return vim.fn.fnamemodify(angular_file, ':h')
end

--- Get Angular core version from package.json
--- @param project_root? string Optional project root path (detects automatically if not provided)
--- @return string The Angular core version, or empty string if not found
function M.get_angular_version(project_root)
  project_root = project_root or M.find_angular_root()

  if not project_root then
    return ''
  end

  local package_json = project_root .. '/package.json'

  if not vim.uv.fs_stat(package_json) then
    return ''
  end

  local f = io.open(package_json, 'r')
  if not f then
    return ''
  end

  local contents = f:read '*a'
  f:close()

  local ok, json = pcall(vim.json.decode, contents)

  if not ok or not json.dependencies then
    return ''
  end

  local angular_core_version = json.dependencies['@angular/core']
  angular_core_version = angular_core_version and angular_core_version:match '%d+%.%d+%.%d+'

  return angular_core_version or ''
end

--- Find project's node_modules directory
--- @return string|nil Path to node_modules, or nil if not found
function M.find_node_modules()
  local root_dir = vim.fn.getcwd()
  local node_modules_dir = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]

  if not node_modules_dir then
    return nil
  end

  return vim.fs.dirname(node_modules_dir) .. '/node_modules'
end

return M
