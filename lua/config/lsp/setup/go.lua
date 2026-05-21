local M = {}

function M.goSemanticToken(client)
  if not client or client.name ~= "gopls" then
    return
  end

  -- [0.12-fix] Adjust semantic token priority locally for Go buffers (Fix #15)
  local original_priority = vim.hl.priorities.semantic_tokens
  vim.hl.priorities.semantic_tokens = 95

  -- Restore priority when leaving Go buffers
  vim.api.nvim_create_autocmd("BufLeave", {
    once = false,
    pattern = "*.go",
    callback = function()
      vim.hl.priorities.semantic_tokens = original_priority
    end,
  })

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
