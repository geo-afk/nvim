-- =============================================================================
-- lua/overseer/template/go/sqlc.lua
-- sqlc generate  (https://sqlc.dev)
-- =============================================================================

return {
  name    = "go: sqlc generate",
  builder = function(_params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "sqlc.yaml", "sqlc.yml", "go.mod" })
           or vim.fn.getcwd()
    return {
      name = "sqlc generate",
      cmd  = { "sqlc", "generate" },
      cwd  = cwd,
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        "on_complete_dispose",
      },
      metadata = { tags = { "go", "sqlc" } },
    }
  end,
  params   = {},
  priority = 50,
  tags     = { "go", "sqlc" },
  condition = {
    callback = function(_)
      return vim.fn.executable("sqlc") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "sqlc.yaml", "sqlc.yml" }) ~= nil
    end,
  },
}
