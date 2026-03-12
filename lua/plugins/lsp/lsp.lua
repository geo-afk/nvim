local lsp_servers = {
  'sqls',
  'html',
  'cssls',
  'gopls',
  'vtsls',
  'lua_ls',
  'typos_lsp',
  'angularls',
  'tailwindcss',
  'emmet_language_server',
}

local mason_tools = {
  'gofumpt',
  'goimports',
  'golines',
  'gotests',
  'staticcheck',
  'biome',
  'prettierd',
  'stylua',
  'iferr',
  'gomodifytags',
  -- Add 'sqruff' if needed
}

return {
  {
    'mason-org/mason.nvim',
    cmd = 'Mason',
    build = ':MasonUpdate',
    opts = {
      ui = {
        icons = {
          package_installed = '✓',
          package_pending = '➜',
          package_uninstalled = '✗',
        },
      },
    },
    config = function(_, opts)
      require('mason').setup(opts)
      local mr = require 'mason-registry'
      -- Refresh without callback (fixed for v2.2.1+)
      mr.refresh()
      -- Defer the install loop to avoid blocking
      vim.defer_fn(function()
        for _, tool in ipairs(mason_tools) do
          local pkg = mr.get_package(tool)
          if pkg and not pkg:is_installed() then
            pkg:install()
          end
        end
      end, 100)
    end,
  },
  {
    'mason-org/mason-lspconfig.nvim',
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
      ensure_installed = lsp_servers,
      automatic_installation = true,
    },
  },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'mason-org/mason-lspconfig.nvim',
    },
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              gofumpt = true,
              codelenses = {
                gc_details = false,
                generate = true,
                regenerate_cgo = true,
                run_govulncheck = true,
                test = true,
                tidy = true,
                upgrade_dependency = true,
                vendor = true,
              },
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
              analyses = {
                nilness = true,
                unusedparams = true,
                unusedwrite = true,
                useany = true,
              },
              usePlaceholders = true,
              completeUnimported = true,
              staticcheck = true,
              directoryFilters = { '-.git', '-.vscode', '-.idea', '-.vscode-test', '-node_modules' },
              semanticTokens = true,
            },
          },
        },
      },
    },
    config = function()
      local lsp_config = require 'config.lsp'
      lsp_config.setup_lsps()
      lsp_config.setup()
      vim.lsp.inlay_hint.enable(true)
    end,
  },
}
