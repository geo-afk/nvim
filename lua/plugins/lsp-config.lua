return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "gopls", "sqlls" },
      })

      require("mason-lspconfig").setup_handlers({
        function(server_name)
          require("lspconfig")[server_name].setup({ capabilities = capabilities })
        end,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    --[[ dependencies = { "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local lspconfig = require("lspconfig")
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.gopls.setup({ capabilities = capabilities })
      lspconfig.sqlls.setup({ capabilities = capabilities })
      -- lspconfig.gofumpt.setup({ capabilities = capabilities })

      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "gd", vim.lsp.buf.declaration, {})
      vim.keymap.set({ "n" }, "<leader>ca", vim.lsp.buf.code_action, {})
    end,
    ]]
  },
}
