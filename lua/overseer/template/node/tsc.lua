-- =============================================================================
-- lua/overseer/template/node/tsc.lua
-- tsc --noEmit  (TypeScript type-check, no output files)
-- =============================================================================

return {
  name    = "ts: tsc --noEmit",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "tsconfig.json", "package.json" })
           or vim.fn.getcwd()

    local cmd = { "tsc", "--noEmit" }
    if params.config and params.config ~= "" then
      vim.list_extend(cmd, { "-p", params.config })
    end
    if params.watch then
      table.insert(cmd, "--watch")
    end

    local components
    if params.watch then
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
      }
    else
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        {
          "on_output_parse",
          problem_matcher = {
            {
              -- TypeScript: src/file.ts(10,5): error TS2322: ...
              pattern = {
                { regexp = "^(.+)%((%d+),(%d+)%): (error|warning) TS%d+: (.+)$",
                  file = 1, line = 2, column = 3, severity = 4, message = 5 },
              },
            },
          },
        },
        { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
        "on_complete_dispose",
      }
    end

    return {
      name       = "tsc --noEmit" .. (params.watch and " --watch" or ""),
      cmd        = cmd,
      cwd        = cwd,
      components = components,
      metadata   = { tags = { "node", "ts", "tsc" } },
    }
  end,
  params = {
    config = {
      type        = "string",
      name        = "Config",
      description = "Path to tsconfig.json",
      optional    = true,
    },
    watch = {
      type     = "boolean",
      name     = "Watch mode",
      optional = true,
      default  = false,
    },
  },
  priority = 70,
  tags     = { "node", "ts", "tsc" },
  condition = {
    filetype = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    callback = function(_)
      return vim.fn.executable("tsc") == 1
        and vim.fs.root(vim.fn.expand("%:p:h"), { "tsconfig.json" }) ~= nil
    end,
  },
}
