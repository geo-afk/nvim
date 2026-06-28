-- =============================================================================
-- lua/overseer/template/go/templ.lua
-- templ generate  (https://github.com/a-h/templ)
-- =============================================================================

return {
  name    = "go: templ generate",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
           or vim.fn.getcwd()

    local cmd = { "templ", "generate" }
    if params.watch then
      table.insert(cmd, "-watch")
    end
    if params.dir and params.dir ~= "" then
      vim.list_extend(cmd, { "-f", params.dir })
    end

    local components
    if params.watch then
      -- Watch mode runs persistently
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
      }
    else
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        "on_complete_dispose",
      }
    end

    return {
      name       = "templ generate" .. (params.watch and " --watch" or ""),
      cmd        = cmd,
      cwd        = cwd,
      components = components,
      metadata   = { tags = { "go", "templ" } },
    }
  end,
  params = {
    watch = {
      type        = "boolean",
      name        = "Watch mode",
      description = "Keep watching for .templ file changes",
      optional    = true,
      default     = false,
    },
    dir = {
      type        = "string",
      name        = "Directory",
      description = "Directory filter for generation",
      optional    = true,
    },
  },
  priority = 45,
  tags     = { "go", "templ" },
  condition = {
    callback = function(_)
      return vim.fn.executable("templ") == 1
    end,
  },
}
