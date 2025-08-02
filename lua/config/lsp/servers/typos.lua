local handlers = require("config.lsp.handlers")

return {
  capabilities = handlers.get_capabilities(),
  on_attach = handlers.on_attach,
  settings = {
    typos_lsp = {
      config = vim.fn.expand("~/AppData/Local/nvim/typos.toml"),
    },
  },
}
