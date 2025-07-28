local lsp_util = require("constants.lsp_util")

return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason").setup()
      local lsp_config = require("config.lsp")

      require("mason-lspconfig").setup({
        ensure_installed = lsp_util.mason_lsp,
      })

      require("mason-lspconfig").setup_handlers({
        -- Default handler
        function(server_name)
          local config = lsp_config.get_server_config(server_name)
          require("lspconfig")[server_name].setup(config)
        end,
      })

      vim.diagnostic.config(lsp_util.diagnostic)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = true,
      },
    },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      vim.defer_fn(function()
        require("mason-tool-installer").setup({
          ensure_installed = lsp_util.mason_tool_install,
          auto_update = false,
          run_on_start = false,
        })
        vim.cmd("MasonToolsInstall")
      end, 500)
    end,
  },
}
