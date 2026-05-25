local utils = require("utils")

-- ============================================================================
-- Path Resolution
-- ============================================================================

--- Get Mason's angular-language-server node_modules path
--- @return string|nil Path to node_modules, or nil if not found
local function get_mason_angular_ls_path()
  local node_modules_path = utils.get_mason_pkg_path("angular-language-server", "/node_modules")

  if node_modules_path then
    return node_modules_path
  end

  -- Log error if Mason package not found
  vim.notify("Could not find Mason angular-language-server installation", vim.log.levels.ERROR)
  return nil
end

--- Get project's node_modules directory
--- @param path? string|integer File path or buffer number to resolve from
--- @return string|nil Path to node_modules, or nil if not found
local function get_project_node_modules(path)
  return utils.find_node_modules(path)
end

-- ============================================================================
-- Configuration Builder
-- ============================================================================

--- Build paths and command configuration for Angular Language Server
--- @param path? string|integer File path or buffer number to resolve from
--- @return table Configuration with cmd array
local function build_angular_ls_config(path)
  -- Get required paths
  local mason_nm = get_mason_angular_ls_path()
  local project_nm = get_project_node_modules(path)
  local angular_root = utils.find_angular_root(path)
  local angular_version = utils.get_angular_version(angular_root)

  -- Collect probe directories
  local ts_probes = {}
  local ng_probes = {}

  -- Add Mason paths (higher priority)
  if mason_nm then
    -- Angular LS in Mason has its own node_modules with typescript and language-service
    local mason_inner_nm = vim.fs.joinpath(mason_nm, "@angular", "language-server", "node_modules")
    table.insert(ts_probes, mason_inner_nm)
    table.insert(ng_probes, mason_inner_nm)
    -- Also include the base node_modules just in case
    table.insert(ts_probes, mason_nm)
    table.insert(ng_probes, mason_nm)
  end

  -- Add project paths
  if project_nm and project_nm ~= "" then
    table.insert(ts_probes, project_nm)
    table.insert(ng_probes, project_nm)
  end

  -- Join into comma-separated strings
  local ts_probe_str = table.concat(ts_probes, ",")
  local ng_probe_str = table.concat(ng_probes, ",")

  local cmd = {
    "ngserver",
    "--stdio",
    "--tsProbeLocations",
    ts_probe_str,
    "--ngProbeLocations",
    ng_probe_str,
  }

  if angular_version and angular_version ~= "" then
    table.insert(cmd, "--angularCoreVersion")
    table.insert(cmd, angular_version)
  end

  table.insert(cmd, "--includeCompletionsForModuleExports")
  table.insert(cmd, "true")

  -- Return command configuration
  return {
    cmd = cmd,
  }
end

-- ============================================================================
-- Export Configuration
-- ============================================================================

local M = {}

function M.build_cmd(path)
  local config = build_angular_ls_config(path)
  return config.cmd
end

return M
