local M = {}
function M.setup()
  local handlers = require("config.lsp.handlers")

  -- Setup global keymaps
  handlers.setup_keymaps()

  -- Enable inlay hints globally
  -- vim.lsp.inlay_hint.enable(true)

  -- Auto-enable inlay hints when LSP attaches
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      -- Ensure client is a table and supports inlay hints
      if
        client
        and type(client) == "table"
        and client.supports_method
        and client.supports_method("textDocument/inlayHint")
      then
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      end
    end,
  })
end

-- Server configurations mapping
M.servers = {
  ts_ls = "typescript",
  gopls = "go",
  lua_ls = "lua_ls",
  typos_lsp = "typos",
}

function M.get_server_config(server_name)
  local config_name = M.servers[server_name]
  if config_name then
    return require("config.lsp.servers." .. config_name)
  end

  -- Default config for servers without specific configuration
  return {
    capabilities = require("config.lsp.handlers").get_capabilities(),
    on_attach = require("config.lsp.handlers").on_attach,
  }
end

return M
