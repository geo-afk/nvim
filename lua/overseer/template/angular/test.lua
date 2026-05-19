-- =============================================================================
-- lua/overseer/template/angular/test.lua
-- ng test
-- =============================================================================

return {
  name    = "ng: test",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json", "package.json" })
           or vim.fn.getcwd()

    local cmd = { "ng", "test" }
    if params.project and params.project ~= "" then
      vim.list_extend(cmd, { "--project", params.project })
    end
    if params.watch == false then
      table.insert(cmd, "--watch=false")
    end
    if params.code_coverage then
      table.insert(cmd, "--code-coverage")
    end
    if params.browsers and params.browsers ~= "" then
      vim.list_extend(cmd, { "--browsers", params.browsers })
    end

    local is_watch = params.watch ~= false

    local components
    if is_watch then
      components = {
        { "display_duration",   detail_level = 2 },
        "on_output_summarize",
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
      }
    else
      components = {
        { "display_duration",   detail_level = 2 },
        "on_output_summarize",
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        "on_complete_dispose",
      }
    end

    return {
      name       = "ng test" .. (is_watch and " --watch" or ""),
      cmd        = cmd,
      cwd        = cwd,
      components = components,
      metadata   = { tags = { "angular", "test" } },
    }
  end,
  params = {
    project = {
      type     = "string",
      name     = "Project",
      optional = true,
      default  = "",
    },
    watch = {
      type     = "boolean",
      name     = "Watch mode",
      optional = true,
      default  = false,
    },
    code_coverage = {
      type     = "boolean",
      name     = "Code coverage",
      optional = true,
      default  = false,
    },
    browsers = {
      type        = "string",
      name        = "Browsers",
      description = "e.g. ChromeHeadless",
      optional    = true,
      default     = "ChromeHeadless",
    },
  },
  priority = 92,
  tags     = { "angular", "test" },
  condition = {
    callback = function(_)
      return vim.fn.executable("ng") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json" }) ~= nil
    end,
  },
}
