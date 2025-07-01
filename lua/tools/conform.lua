return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" }, -- or "BufWritePre" for save-only loading
  opts = {
    notify_on_error = true,
    formatters = {
      prettier = {
        prepend_args = {
          "--tab-width",
          "2",
          "--use-tabs",
          "false",
          "--semi",
          "--single-quote",
          "--quote-props",
          "as-needed",
          "--trailing-comma",
          "es5",
          "--bracket-spacing",
          "--bracket-same-line",
          "false",
          "--arrow-parens",
          "avoid",
          "--html-whitespace-sensitivity",
          "ignore",
          "--end-of-line",
          "lf",
          "--embedded-language-formatting",
          "auto",
          "--single-attribute-per-line",
          "false",
        },
        require_cwd = false, -- Set to false if you want Prettier to work without a config file
      },
    },
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "black" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      json = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" }, -- Optional: Add more filetypes as needed
    },
  },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format code with Conform",
    },
  },
}
