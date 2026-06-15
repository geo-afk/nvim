local M = {}
local semantic_priority_set = false

function M.goSemanticToken(client)
  if not client or client.name ~= "gopls" then
    return
  end

  -- [0.12-fix] Adjust semantic token priority locally for Go buffers (Fix #15)
  if not semantic_priority_set then
    vim.hl.priorities.semantic_tokens = 95
    semantic_priority_set = true
  end

  -- Fix #24: Harmess workaround for older gopls versions
  if client.server_capabilities.semanticTokensProvider == nil then
    local semantic = client.config and client.config.capabilities and client.config.capabilities.textDocument
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
