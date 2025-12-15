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
local extension_path = get_mason_extension_path()
if not extension_path then
  vim.notify('Could not find Mason angular-language-server installation at expected location', vim.log.levels.ERROR)
  vim.notify('Expected: ' .. vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules', vim.log.levels.INFO)
  extension_path = '?'
end

local default_probe_dir = get_probe_dir()

return {
  root_markers = { 'angular.json', '.git', 'package.json', 'tsconfig.json', 'jsconfig.json' },
  init_options = { hostInfo = 'neovim' },
  settings = {
    complete_function_calls = true,
    vtsls = {
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        maxInlayHintLength = 30,
        completion = {
          enableServerSideFuzzyMatch = true,
          entriesLimit = 50,
        },
      },
    },
    tsserver = {
      globalPlugins = {
        {
          name = '@angular/language-server',
          location = vim.iter({ extension_path, default_probe_dir }):join ',',
          enableForWorkspaceTypeScriptVersions = false,
        },
      },
    },
    typescript = {
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      implementationCodeLens = {
        enabled = true,
        showOnInterfaceMethods = true,
      },
      updateImportsOnFileMove = { enabled = 'always' },
      suggest = {
        completeFunctionCalls = true,
      },
      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = 'literals' },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = true },
      },
    },
    javascript = {
      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = 'literals' },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = true },
      },
    },
  },
}
