local utils = require 'utils'

-- ============================================================================
-- Path Resolution
-- ============================================================================

--- Get Mason's angular-language-server node_modules path
--- @return string|nil Path to node_modules, or nil if not found
local function get_mason_angular_ls_path()
  local node_modules_path = utils.get_mason_pkg_path('angular-language-server', '/node_modules')

  if node_modules_path then
    return node_modules_path
  end

  -- Log error if Mason package not found
  vim.notify('Could not find Mason angular-language-server installation', vim.log.levels.ERROR)
  vim.notify('Expected: ' .. vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules', vim.log.levels.INFO)

  return nil
end

--- Get project's node_modules directory
--- @param path? string|integer File path or buffer number to resolve from
--- @return string Path to node_modules, or empty string if not found
local function get_project_node_modules(path)
  local node_modules = utils.find_node_modules(path)
  return node_modules or ''
end

-- ============================================================================
-- Configuration Builder
-- ============================================================================

--- Build paths and command configuration for Angular Language Server
--- @param path? string|integer File path or buffer number to resolve from
--- @return table Configuration with cmd array
local function build_angular_ls_config(path)
  -- Get required paths
  local mason_extension_path = get_mason_angular_ls_path()
  local project_node_modules = get_project_node_modules(path)
  local angular_root = utils.find_angular_root(path)
  local angular_version = utils.get_angular_version(angular_root)

  -- Use placeholder if Mason path not found (prevents crash)
  mason_extension_path = mason_extension_path or '?'

  -- Build probe directories for TypeScript
  local ts_probe_dirs = vim.iter({ mason_extension_path, project_node_modules }):join ','

  -- Build probe directories for Angular (includes subdirectory)
  local ng_probe_dirs = vim
    .iter({ mason_extension_path, project_node_modules })
    :map(function(p)
      return vim.fs.joinpath(p, '@angular/language-server/node_modules')
    end)
    :join ','

  -- Return command configuration
  return {
    cmd = {
      'ngserver',
      '--stdio',
      '--tsProbeLocations',
      ts_probe_dirs,
      '--ngProbeLocations',
      ng_probe_dirs,
      '--angularCoreVersion',
      angular_version,
    },
  }
end

-- ============================================================================
-- Export Configuration
-- ============================================================================

return build_angular_ls_config()
