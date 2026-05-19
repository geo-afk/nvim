-- =============================================================================
-- lua/overseer/template/node/jest.lua
-- jest  – classic JS/TS test runner
-- =============================================================================

return {
  name    = "node: jest",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), {
      "jest.config.ts", "jest.config.js", "jest.config.cjs", "package.json",
    }) or vim.fn.getcwd()

    local cmd = { "npx", "--no-install", "jest", "--colors" }
    if params.watch then
      table.insert(cmd, "--watch")
    else
      table.insert(cmd, "--watchAll=false")
    end
    if params.file and params.file ~= "" then
      table.insert(cmd, params.file)
    end
    if params.coverage then
      table.insert(cmd, "--coverage")
    end

    local components
    if params.watch then
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
      name       = "jest" .. (params.watch and " --watch" or ""),
      cmd        = cmd,
      cwd        = cwd,
      components = components,
      metadata   = { tags = { "node", "jest", "test" } },
    }
  end,
  params = {
    watch = {
      type     = "boolean",
      name     = "Watch mode",
      optional = true,
      default  = false,
    },
    file = {
      type     = "string",
      name     = "File / pattern",
      optional = true,
    },
    coverage = {
      type     = "boolean",
      name     = "Coverage",
      optional = true,
      default  = false,
    },
  },
  priority = 86,
  tags     = { "node", "jest", "test" },
  condition = {
    filetype = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    callback = function(_)
      return vim.fn.executable("npx") == 1
        and vim.fs.root(
          vim.fn.expand("%:p:h"),
          { "jest.config.ts", "jest.config.js", "jest.config.cjs" }
        ) ~= nil
    end,
  },
}
