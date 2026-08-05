local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local config = require("config.lsp.servers.go")
local settings = config.settings.gopls

assert_equal(settings.semanticTokens, false, "gopls semantic tokens must remain disabled")
assert_equal(settings.diagnosticsDelay, "1s", "deep diagnostics should retain the upstream debounce")
assert_equal(settings.staticcheck, false, "full staticcheck must not run during normal editing")
assert_equal(settings.vulncheck, "Off", "automatic vulnerability scanning must remain disabled")
assert_equal(settings.codelenses.gc_details, false, "compiler-detail lenses must remain disabled")
assert_equal(settings.codelenses.run_govulncheck, false, "vulnerability lenses must remain disabled")

local expected_filters = {
  "-**/.git",
  "-**/node_modules",
  "-**/vendor",
  "-**/tmp",
  "-**/dist",
}
assert_equal(settings.directoryFilters, expected_filters, "workspace exclusions must apply recursively")

local go_setup = require("config.lsp.setup.go")
local original_priority = vim.hl.priorities.semantic_tokens
local client = {
  name = "gopls",
  server_capabilities = {},
  config = {
    capabilities = {
      textDocument = {
        semanticTokens = {
          tokenTypes = { "variable" },
          tokenModifiers = {},
        },
      },
    },
  },
}

go_setup.goSemanticToken(client)
assert_equal(client.server_capabilities.semanticTokensProvider, nil, "missing server capability must not be spoofed")
assert_equal(vim.hl.priorities.semantic_tokens, original_priority, "disabled semantic tokens must not alter global priority")

print("Go performance configuration passed")
