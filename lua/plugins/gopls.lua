return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("lspconfig").gopls.setup({
        settings = {
          gopls = {
            gofumpt = true,
          },
        },
      })
    end,
  },
}
