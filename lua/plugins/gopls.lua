return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("lspconfig").gopls.setup({
        settings = {
          gopls = {
            gofumpt = true,
            hints = {
              rangeVariableTypes = true,
              parameterNames = true,
              constantValues = true,
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              functionTypeParameters = true,
            },
          },
        },
      })
    end,
  },
}
