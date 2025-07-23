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
      -- Ensure mason is setup first
      require("mason").setup()

      local original_capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require("blink.cmp").get_lsp_capabilities(original_capabilities)

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "gopls",
          "sqlls",
          "html",
          "angularls",
          "tailwindcss",
          "ts_ls", -- Modern TypeScript/JavaScript LSP (replaces tsserver)
          -- Removed typos_lsp as it's often problematic
        },
      })

      require("mason-lspconfig").setup_handlers({
        function(server_name)
          require("lspconfig")[server_name].setup({ capabilities = capabilities })
        end,
      })

      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
        } or {},
        virtual_text = {
          source = "if_many",
          spacing = 2,
          format = function(diagnostic)
            return diagnostic.message
          end,
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Get Descriptions" })
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })
      vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Go to References" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Actions" })
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename Symbol" })
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to Implementation" })
      vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature Help" })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      -- Delay to ensure mason is ready
      vim.defer_fn(function()
        require("mason-tool-installer").setup({
          ensure_installed = {
            -- Go tools
            "gofumpt",
            "goimports",
            "golines",
            "gotests",
            "staticcheck",

            -- General formatters/linters
            "prettier",
            "stylua",
            "eslint_d", -- Faster than eslint

            -- Optional: Add based on your needs
            -- "jsonls",
            -- "marksman", -- Markdown LSP
          },
          auto_update = false, -- Prevent startup conflicts
          run_on_start = false, -- Manual installation to avoid race conditions
        })

        -- Manually trigger installation after setup
        vim.cmd("MasonToolsInstall")
      end, 500) -- 500ms delay
    end,
  },
}
