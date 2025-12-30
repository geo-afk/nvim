local lsp_tools = {
  -- Go tools
  'gofumpt',
  'goimports',
  'golines',
  'gotests',
  'staticcheck',
  'biome',
  -- General formatters/linters
  -- 'prettier',
  'prettierd',
  'stylua',
  -- 'eslint_d', -- Faster than eslint
  'gotests',
  'iferr',
  -- 'sqruff',
  'gomodifytags',
  -- Optional: Add based on your needs
  -- "jsonls",
  -- "marksman", -- Markdown LSP
}

local mason_lsp = {
  'sqls',
  'html',
  'cssls',
  'gopls',
  -- 'ts_ls',
  'lua_ls',
  'typos_lsp',
  'angularls',
  'tailwindcss',
  'emmet_language_server',
}

return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    {
      'mason-org/mason.nvim',
      cmd = 'Mason',
      build = ':MasonUpdate',
      opts = {},
      config = function(_, opts)
        require('mason').setup(opts)
        local mr = require 'mason-registry'
        mr:on('package:install:success', function()
          vim.defer_fn(function()
            -- trigger FileType event to possibly load this newly installed LSP server
            require('lazy.core.handler.event').trigger {
              event = 'FileType',
              buf = vim.api.nvim_get_current_buf(),
            }
          end, 100)
        end)

        mr.refresh(function()
          for _, tool in ipairs(lsp_tools) do
            local p = mr.get_package(tool)
            if not p:is_installed() then
              p:install()
            end
          end
        end)
      end,
    },
    'mason-org/mason-lspconfig.nvim',
  },
  opts = {
    inlay_hints = { enabled = true },
  },
  config = function()
    local lsp_config = require 'config.lsp'

    local mr = require 'mason-registry'

    mr.refresh(function()
      for _, tool in ipairs(lsp_tools) do
        local p = mr.get_package(tool)
        if not p:is_installed() then
          p:install()
        end
      end
    end)

    require('mason').setup {
      ui = {
        icons = {
          package_installed = '✓',
          package_pending = '➜',
          package_uninstalled = '✗',
        },
      },
    }
    require('mason-lspconfig').setup {
      ensure_installed = mason_lsp,
      automatic_installation = false,
    }
    lsp_config.setup_lsps()
    lsp_config.setup()
  end,
}
