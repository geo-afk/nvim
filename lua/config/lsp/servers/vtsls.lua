local pkg = require 'utils.mason-pkg'
local utils = require 'utils'

local function get_global_plugin()
  -- Return an empty list by default
  if not utils.is_angular_project() then
    return {}
  end

  local angular_ls_path = pkg.get_pkg_path('angular-language-server', '/node_modules/@angular/language-server')

  -- If the language server is not installed, fail gracefully
  if not angular_ls_path then
    return {}
  end

  return {
    {
      name = '@angular/language-server',
      location = angular_ls_path,
      enableForWorkspaceTypeScriptVersions = false,
    },
  }
end

return {
  root_markers = { 'angular.json', '.git', 'package.json', 'tsconfig.json', 'jsconfig.json' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
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
      globalPlugins = get_global_plugin(),
    },
    typescript = {
      preferences = {
        importModuleSpecifier = 'relative',
      },
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
