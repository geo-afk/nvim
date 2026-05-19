-- =============================================================================
-- lua/overseer/template/angular/serve.lua
-- ng serve  –  persistent dev server, restartable, background-friendly
-- =============================================================================

return {
  name    = "ng: serve",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json", "package.json" })
           or vim.fn.getcwd()

    local cmd = { "ng", "serve" }
    if params.project and params.project ~= "" then
      vim.list_extend(cmd, { "--project", params.project })
    end
    if params.port and params.port ~= "" then
      vim.list_extend(cmd, { "--port", params.port })
    end
    if params.open then
      table.insert(cmd, "--open")
    end
    if params.hmr then
      table.insert(cmd, "--hmr")
    end
    if params.configuration and params.configuration ~= "" then
      vim.list_extend(cmd, { "--configuration", params.configuration })
    end

    return {
      name = "ng serve" .. (params.project ~= "" and (" [" .. params.project .. "]") or ""),
      cmd  = cmd,
      cwd  = cwd,
      -- Persistent: keep running, never auto-dispose
      components = {
        { "display_duration", detail_level = 2 },
        "on_output_summarize",
        "on_exit_set_status",
        -- Notify only if the server exits unexpectedly (not on manual stop)
        { "on_complete_notify", statuses = { "FAILURE" }, system = "unfocused" },
        -- Restart automatically on unexpected crash
        { "on_complete_restart", statuses = { "FAILURE" }, delay = 2000 },
      },
      metadata = {
        tags            = { "angular", "serve" },
        -- Expose restart_on_save = false (ng serve has its own HMR)
        restart_on_save = false,
        -- Mark as persistent so session serialisation keeps it
        persistent      = true,
      },
    }
  end,
  params = {
    project = {
      type        = "string",
      name        = "Project",
      description = "Angular workspace project name",
      optional    = true,
      default     = "",
    },
    port = {
      type        = "string",
      name        = "Port",
      description = "Dev server port (default: 4200)",
      optional    = true,
      default     = "4200",
    },
    configuration = {
      type        = "string",
      name        = "Configuration",
      description = "Build configuration (e.g. development, production)",
      optional    = true,
      default     = "development",
    },
    open = {
      type     = "boolean",
      name     = "Open browser",
      optional = true,
      default  = false,
    },
    hmr = {
      type     = "boolean",
      name     = "HMR",
      optional = true,
      default  = false,
    },
  },
  priority = 90,
  tags     = { "angular", "serve" },
  condition = {
    callback = function(_)
      return vim.fn.executable("ng") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "angular.json" }) ~= nil
    end,
  },
}
