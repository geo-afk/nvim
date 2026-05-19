-- =============================================================================
-- lua/overseer/template/angular/build.lua
-- ng build  –  production-ready build with diagnostics / quickfix
-- =============================================================================

return {
  name    = "ng: build",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json", "package.json" })
           or vim.fn.getcwd()

    local cmd = { "ng", "build" }
    if params.project and params.project ~= "" then
      vim.list_extend(cmd, { "--project", params.project })
    end
    if params.configuration and params.configuration ~= "" then
      vim.list_extend(cmd, { "--configuration", params.configuration })
    end
    if params.stats_json then
      table.insert(cmd, "--stats-json")
    end

    return {
      name = "ng build" .. (params.configuration ~= "" and (" [" .. params.configuration .. "]") or ""),
      cmd  = cmd,
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
              -- Angular / TypeScript compiler errors
              pattern = {
                { regexp = "^(.+):(%d+):(%d+)%-?%d*: (ERROR|WARNING|error|warning): (.+)$",
                  file = 1, line = 2, column = 3, severity = 4, message = 5 },
                { regexp = "^(.+)%((%d+),(%d+)%): (error|warning) TS%d+: (.+)$",
                  file = 1, line = 2, column = 3, severity = 4, message = 5 },
              },
            },
          },
        },
        { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
        "on_complete_dispose",
      },
      metadata = { tags = { "angular", "build" } },
    }
  end,
  params = {
    project = {
      type     = "string",
      name     = "Project",
      optional = true,
      default  = "",
    },
    configuration = {
      type     = "string",
      name     = "Configuration",
      optional = true,
      default  = "production",
    },
    stats_json = {
      type     = "boolean",
      name     = "Stats JSON",
      optional = true,
      default  = false,
    },
  },
  priority = 91,
  tags     = { "angular", "build" },
  condition = {
    callback = function(_)
      return vim.fn.executable("ng") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json" }) ~= nil
    end,
  },
}
