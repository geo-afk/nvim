-- =============================================================================
-- lua/overseer/template/go/lint.lua
-- golangci-lint run
-- =============================================================================

return {
  name    = "go: golangci-lint",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work", ".golangci.yml" })
           or vim.fn.getcwd()

    local cmd = { "golangci-lint", "run" }
    if params.fix then
      table.insert(cmd, "--fix")
    end
    -- Output format: line-number for quickfix integration
    vim.list_extend(cmd, { "--out-format", "line-number", "--print-issued-lines=false" })
    if params.pkg and params.pkg ~= "" then
      table.insert(cmd, params.pkg)
    else
      table.insert(cmd, "./...")
    end

    return {
      name = "golangci-lint " .. (params.pkg or "./..."),
      cmd  = cmd,
      cwd  = cwd,
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        {
          "on_output_parse",
          problem_matcher = {
            {
              -- golangci-lint line-number format:  file:line:col: message (linter)
              pattern = {
                { regexp = "^(.+):(%d+):(%d+): (.+)$",
                  file = 1, line = 2, column = 3, message = 4 },
                { regexp = "^(.+):(%d+): (.+)$",
                  file = 1, line = 2, message = 3 },
              },
            },
          },
        },
        { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
        "on_complete_dispose",
      },
      metadata = { tags = { "go", "lint" } },
    }
  end,
  params = {
    pkg = {
      type        = "string",
      name        = "Package",
      description = "Package pattern (default: ./...)",
      optional    = true,
    },
    fix = {
      type        = "boolean",
      name        = "Fix",
      description = "Apply auto-fixes",
      optional    = true,
      default     = false,
    },
  },
  priority = 35,
  tags     = { "go", "lint" },
  condition = {
    filetype = { "go" },
    callback = function(_)
      return vim.fn.executable("golangci-lint") == 1
    end,
  },
}
