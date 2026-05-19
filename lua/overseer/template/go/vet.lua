-- =============================================================================
-- lua/overseer/template/go/vet.lua
-- go vet ./...
-- =============================================================================

return {
  name    = "go: vet (./...)",
  builder = function(_params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
           or vim.fn.getcwd()
    return {
      name = "go vet ./...",
      cmd  = { "go", "vet", "./..." },
      cwd  = cwd,
      components = {
        { "display_duration",   detail_level = 2 },
        "on_output_summarize",
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        {
          "on_output_parse",
          problem_matcher = {
            {
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
      metadata = { tags = { "go", "vet" } },
    }
  end,
  params   = {},
  priority = 30,
  tags     = { "go", "vet" },
  condition = { filetype = { "go" } },
}
