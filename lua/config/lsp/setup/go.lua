local M = {}
local semantic_priority_set = false

function M.goSemanticToken(client)
  if
    not client
    or client.name ~= "gopls"
    or not client.server_capabilities
    or client.server_capabilities.semanticTokensProvider == nil
  then
    return
  end

  -- If semantic tokens are explicitly enabled again, keep them below
  -- Treesitter highlights instead of manufacturing an unsupported provider.
  if not semantic_priority_set then
    vim.hl.priorities.semantic_tokens = 95
    semantic_priority_set = true
  end
end

return M
