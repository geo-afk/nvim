-- Safely load dependencies
local ok_pkg, pkg = pcall(require, "utils.mason-pkg")
local ok_utils, utils = pcall(require, "utils")

if not ok_pkg then
  vim.notify("[vtsls] utils.mason-pkg not found", vim.log.levels.WARN)
end

if not ok_utils then
  vim.notify("[vtsls] utils module not found", vim.log.levels.WARN)
end

local function get_global_plugin()
  -- ensure utils exists
  if not ok_utils or not utils.is_angular_project then
    return {}
  end

  -- only enable for angular projects
  local ok_project, is_angular = pcall(utils.is_angular_project)
  if not ok_project or not is_angular then
    return {}
  end

  -- ensure pkg exists
  if not ok_pkg or not pkg.get_pkg_path then
    return {}
  end

  -- safely get mason path
  local ok_path, angular_ls_path =
    pcall(pkg.get_pkg_path, "angular-language-server", "/node_modules/@angular/language-server")

  if not ok_path or not angular_ls_path then
    return {}
  end

  return {
    {
      name = "@angular/language-server",
      location = angular_ls_path,
      enableForWorkspaceTypeScriptVersions = false,
    },
  }
end

return {
  cmd = { "vtsls", "--stdio" },
  root_markers = { "angular.json", ".git", "package.json", "tsconfig.json", "jsconfig.json" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  init_options = { hostInfo = "neovim" },

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
        importModuleSpecifier = "relative",
      },

      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },

      implementationCodeLens = {
        enabled = true,
        showOnInterfaceMethods = true,
      },

      updateImportsOnFileMove = { enabled = "always" },

      suggest = {
        completeFunctionCalls = true,
      },

      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = true },
      },
    },

    javascript = {
      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = true },
      },
    },
  },
}
