-- Detect the project root
local root_dir = vim.fn.getcwd()
local node_modules_dir = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]
local project_root = node_modules_dir and vim.fs.dirname(node_modules_dir) or nil

-- Get npm global root for extension_path
local function get_extension_path()
  local npm_root = vim.fn.systemlist('npm root -g')[1]
  if not npm_root or npm_root == '' then
    return nil
  end
  return vim.fs.normalize(npm_root)
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

-- Build paths
local extension_path = get_extension_path() or '?'
local default_probe_dir = get_probe_dir()
local default_angular_core_version = get_angular_core_version()

-- AngularLS expects structure like:
-- - $EXTENSION_PATH
--   - @angular/language-server/bin/ngserver
--   - typescript/
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
        server = 'off', -- Options: "off", "messages", "verbose"
      },
    },
  },
  cmd = cmd,
  root_markers = { 'angular.json', 'nx.json' },
  filetypes = { 'javascript', 'typescript', 'html', 'typescriptreact', 'typescript.tsx', 'htmlangular' },
}
