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

local uv = vim.uv or vim.loop

local function path_exists(path)
  return path and uv.fs_stat(path) ~= nil
end

local function normalize_dir(path)
  if not path or path == "" then
    return nil
  end

  local normalized = vim.fs.normalize(path)
  local stat = uv.fs_stat(normalized)
  if stat and stat.type == "file" then
    return vim.fs.dirname(normalized)
  end

  return normalized
end

local function resolve_start_dir(path)
  if type(path) == "number" then
    local bufname = vim.api.nvim_buf_get_name(path)
    if bufname ~= "" then
      return normalize_dir(bufname)
    end
  end

  if type(path) == "string" and path ~= "" then
    return normalize_dir(path)
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    return normalize_dir(bufname)
  end

  return normalize_dir(vim.fn.getcwd())
end

local function read_json_file(path)
  if not path_exists(path) then
    return nil
  end

  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local contents = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, contents)
  if ok then
    return decoded
  end

  return nil
end

local function package_has_angular(package_json)
  if type(package_json) ~= "table" then
    return false
  end

  for _, section in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
    local deps = package_json[section]
    if type(deps) == "table" and deps["@angular/core"] then
      return true
    end
  end

  return false
end

local function project_json_has_angular(project_json)
  if type(project_json) ~= "table" then
    return false
  end

  if type(project_json.tags) == "table" then
    for _, tag in ipairs(project_json.tags) do
      if type(tag) == "string" and tag:lower():find("angular", 1, true) then
        return true
      end
    end
  end

  local targets = project_json.targets or project_json.architect
  if type(targets) ~= "table" then
    return false
  end

  for _, target in pairs(targets) do
    if type(target) == "table" then
      local executor = target.executor or target.builder
      if type(executor) == "string" and executor:find("angular", 1, true) then
        return true
      end
    end
  end

  return false
end

local function has_angular_project_marker(dir)
  if not dir then
    return false
  end

  if path_exists(vim.fs.joinpath(dir, "angular.json")) then
    return true
  end

  if project_json_has_angular(read_json_file(vim.fs.joinpath(dir, "project.json"))) then
    return true
  end

  if package_has_angular(read_json_file(vim.fs.joinpath(dir, "package.json"))) then
    return true
  end

  return false
end

local function find_upward(start_dir, predicate)
  local dir = resolve_start_dir(start_dir)

  while dir do
    if predicate(dir) then
      return dir
    end

    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end

  return nil
end



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
--- @param path? string|integer Optional file path or buffer number
--- @return boolean True if angular.json exists in current or parent directories
function M.is_angular_project(path)
  return M.find_angular_root(path) ~= nil
end

--- Find the Angular project root directory
--- @param path? string|integer Optional file path or buffer number
--- @return string|nil The project root path, or nil if not found
function M.find_angular_root(path)
  return find_upward(path, function(dir)
    if path_exists(vim.fs.joinpath(dir, "angular.json")) then
      return true
    end

    local has_nx_root = path_exists(vim.fs.joinpath(dir, "nx.json"))
    if not has_nx_root then
      return false
    end

    return has_angular_project_marker(dir)
  end)
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

  local json = read_json_file(package_json)
  if not json then
    return ''
  end

  local angular_core_version = nil
  for _, section in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
    if type(json[section]) == "table" and json[section]["@angular/core"] then
      angular_core_version = json[section]["@angular/core"]
      break
    end
  end

  angular_core_version = angular_core_version and angular_core_version:match '%d+%.%d+%.%d+'

  return angular_core_version or ''
end

--- Find project's node_modules directory
--- @param path? string|integer Optional file path or buffer number
--- @return string|nil Path to node_modules, or nil if not found
function M.find_node_modules(path)
  local root_dir = resolve_start_dir(path)
  if not root_dir then
    return nil
  end

  local node_modules_dir = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]

  if not node_modules_dir then
    return nil
  end

  return vim.fs.dirname(node_modules_dir) .. '/node_modules'
end

return M
