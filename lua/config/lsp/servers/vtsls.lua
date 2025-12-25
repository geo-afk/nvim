local pkg = require 'utils.mason-pkg'

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
          location = pkg.get_pkg_path('angular-language-server', '/node_modules/@angular/language-server'),
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
