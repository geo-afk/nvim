local handlers = require("config.lsp.handlers")

return {
  capabilities = handlers.get_capabilities(),
  on_attach = handlers.on_attach,
  settings = {
    Lua = {
      hint = {
        enable = true,
        arrayIndex = "Auto",
        await = true,
        paramName = "All",
        paramType = true,
        semicolon = "All",
        setType = false,
      },
    },
  },
}
