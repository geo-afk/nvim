-- Detect the project root
local root_dir = vim.fn.getcwd()
local node_modules_dir = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]
local project_root = node_modules_dir and vim.fs.dirname(node_modules_dir) or nil

-- Get Mason's angular-language-server node_modules path
local function get_mason_extension_path()
  -- Use stdpath directly to get the correct Mason data directory
  local mason_path = vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server'
  local node_modules_path = vim.fs.joinpath(mason_path, 'node_modules')

  -- Normalize the path for Windows compatibility
  node_modules_path = vim.fs.normalize(node_modules_path)

  -- Check if the path exists
  if vim.uv.fs_stat(node_modules_path) then
    return node_modules_path
  end

  -- Try with mason-registry as fallback
  local ok, mason_registry = pcall(require, 'mason-registry')
  if ok then
    local angular_ls_pkg = mason_registry.get_package 'angular-language-server'
    if angular_ls_pkg:is_installed() then
      local install_path = angular_ls_pkg:get_install_path()
      local registry_path = vim.fs.joinpath(install_path, 'node_modules')
      if vim.uv.fs_stat(registry_path) then
        return vim.fs.normalize(registry_path)
      end
    end
  end

  return nil
end

-- Probe dir (local project node_modules)
local function get_probe_dir()
  return project_root and (project_root .. '/node_modules') or ''
end

-- Extract Angular core version from package.json
local function get_angular_core_version()
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

-- Build paths using Mason's angular-language-server
local extension_path = get_mason_extension_path()
if not extension_path then
  vim.notify('Could not find Mason angular-language-server installation at expected location', vim.log.levels.ERROR)
  vim.notify('Expected: ' .. vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules', vim.log.levels.INFO)
  extension_path = '?'
end

local default_probe_dir = get_probe_dir()
local default_angular_core_version = get_angular_core_version()

local ts_probe_dirs = vim.iter({ extension_path, default_probe_dir }):join ','
local ng_probe_dirs = vim
  .iter({ extension_path, default_probe_dir })
  :map(function(p)
    return vim.fs.joinpath(p, '/@angular/language-server/node_modules')
  end)
  :join ','

local cmd = {
  'ngserver',
  '--stdio',
  '--tsProbeLocations',
  ts_probe_dirs,
  '--ngProbeLocations',
  ng_probe_dirs,
  '--angularCoreVersion',
  default_angular_core_version,
}

return {
  settings = {
    angularls = {
      experimental = {
        templateDiagnostics = true, -- Enable diagnostics for Angular templates
        templateCodeLens = true, -- Enable code lenses for template-related actions
      },
      provideFormatter = true, -- Enable formatting support for Angular files
      strictTemplates = true, -- Enforce strict template type checking
      trace = {
        server = 'messages', -- Options: "off", "messages", "verbose"
      },
    },
  },
  cmd = cmd,
  root_markers = { 'angular.json', 'nx.json' },
  filetypes = { 'htmlangular' },
}
