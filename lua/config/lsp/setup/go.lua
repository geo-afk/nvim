local M = {}

function M.goSemanticToken(client)
  if not client or client.name ~= 'gopls' then
    return
  end
  if client.server_capabilities.semanticTokensProvider == nil then
    local semantic = client.config
      and client.config.capabilities
      and client.config.capabilities.textDocument
      and client.config.capabilities.textDocument.semanticTokens
    if semantic then
      client.server_capabilities.semanticTokensProvider = {
        full = true,
        legend = {
          tokenTypes = semantic.tokenTypes,
          tokenModifiers = semantic.tokenModifiers,
        },
        range = true,
      }
    end
  end
end

return M
