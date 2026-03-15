-- LSP servers (lspconfig names)
local lsp_servers = {
  "sqls",
  "html",
  "cssls",
  "gopls",
  "vtsls",
  "lua_ls",
  "typos_lsp",
  "angularls",
  "tailwindcss",
  "emmet_language_server",
}

-- Formatters / linters / utilities
local mason_tools = {
  "gofumpt",
  "goimports",
  "golines",
  "gotests",
  "staticcheck",
  "biome",
  "prettierd",
  "stylua",
  "iferr",
  "gomodifytags",
}

-- Map LSP names → Mason package names
local lsp_to_mason = {
  lua_ls = "lua-language-server",
  angularls = "angular-language-server",
  emmet_language_server = "emmet-language-server",
  vtsls = "vtsls",
  gopls = "gopls",
  html = "html-lsp",
  cssls = "css-lsp",
  sqls = "sqls",
  tailwindcss = "tailwindcss-language-server",
  typos_lsp = "typos-lsp",
}

-- Convert LSP list → mason package names
local function get_lsp_packages()
  local packages = {}

  for _, lsp in ipairs(lsp_servers) do
    local mason_name = lsp_to_mason[lsp] or lsp
    table.insert(packages, mason_name)
  end

  return packages
end

return {
  -------------------------------------------------
  -- Mason package manager
  -------------------------------------------------
  {
    "mason-org/mason.nvim",
    lazy = false,
    build = ":MasonUpdate",

    keys = {
      { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason UI" },
    },

    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },

    config = function(_, opts)
      require("mason").setup(opts)

      local registry = require("mason-registry")

      -- Merge all packages
      local ensure_installed = {}

      vim.list_extend(ensure_installed, get_lsp_packages())
      vim.list_extend(ensure_installed, mason_tools)

      -- extra tools
      -- vim.list_extend(ensure_installed, {
      --   "delve",
      --   "golangci-lint",
      -- })

      registry.refresh(function()
        for _, pkg_name in ipairs(ensure_installed) do
          local ok, pkg = pcall(registry.get_package, pkg_name)

          if ok then
            if not pkg:is_installed() then
              pkg:install():once(
                "install:success",
                vim.schedule_wrap(function()
                  vim.notify("[Mason] Installed: " .. pkg_name, vim.log.levels.INFO)
                end)
              )
            end
          else
            vim.notify("[Mason] Package not found: " .. pkg_name, vim.log.levels.WARN)
          end
        end
      end)
    end,
  },

  -------------------------------------------------
  -- Native LSP config
  -------------------------------------------------
  {
    dir = vim.fn.stdpath("config"),
    name = "lsp-config",
    lazy = false,
    dependencies = {
      "mason-org/mason.nvim",
      "saghen/blink.cmp",
    },

    config = function()
      local lsp_config = require("config.lsp")

      -- enable servers from the list
      for _, server in ipairs(lsp_servers) do
        vim.lsp.enable(server)
      end

      lsp_config.setup_lsps()
      lsp_config.setup()

      vim.lsp.inlay_hint.enable(true)
    end,
  },
}
