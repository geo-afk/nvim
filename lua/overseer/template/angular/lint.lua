-- =============================================================================
-- lua/overseer/template/angular/lint.lua
-- ng lint  –  ESLint via Angular CLI, populate quickfix
-- =============================================================================

return {
  name    = "ng: lint",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json", "package.json" })
           or vim.fn.getcwd()

    local cmd = { "ng", "lint" }
    if params.project and params.project ~= "" then
      vim.list_extend(cmd, { "--project", params.project })
    end
    if params.fix then
      table.insert(cmd, "--fix")
    end
    -- ESLint unix output format gives us clean file:line:col: message entries
    vim.list_extend(cmd, { "--format", "unix" })

    return {
      name = "ng lint" .. (params.project ~= "" and (" [" .. params.project .. "]") or ""),
      cmd  = cmd,
      cwd  = cwd,
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        {
          "on_output_parse",
          problem_matcher = {
            {
              pattern = {
                { regexp = "^(.+):(%d+):(%d+): (.+)$",
                  file = 1, line = 2, column = 3, message = 4 },
              },
            },
          },
        },
        { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
        "on_complete_dispose",
      },
      metadata = { tags = { "angular", "lint" } },
    }
  end,
  params = {
    project = {
      type     = "string",
      name     = "Project",
      optional = true,
      default  = "",
    },
    fix = {
      type     = "boolean",
      name     = "Fix",
      optional = true,
      default  = false,
    },
  },
  priority = 93,
  tags     = { "angular", "lint" },
  condition = {
    callback = function(_)
      return vim.fn.executable("ng") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json" }) ~= nil
    end,
  },
}
