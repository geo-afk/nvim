-- =============================================================================
-- lua/overseer/template/node/vitest.lua
-- vitest  –  unit test runner (Vite-native)
-- =============================================================================

return {
  name    = "node: vitest",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), {
      "vitest.config.ts", "vitest.config.js", "vite.config.ts",
      "vite.config.js", "package.json",
    }) or vim.fn.getcwd()

    local cmd = { "npx", "--no-install", "vitest" }
    if params.run then
      -- One-shot run instead of watch mode
      table.insert(cmd, "run")
    end
    if params.file and params.file ~= "" then
      table.insert(cmd, params.file)
    end
    if params.reporter then
      vim.list_extend(cmd, { "--reporter", params.reporter })
    end

    local is_watch = not params.run

    local components
    if is_watch then
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
      name       = "vitest" .. (is_watch and " --watch" or " run"),
      cmd        = cmd,
      cwd        = cwd,
      components = components,
      metadata   = { tags = { "node", "vitest", "test" } },
    }
  end,
  params = {
    run = {
      type        = "boolean",
      name        = "One-shot (run)",
      description = "Run tests once instead of watching",
      optional    = true,
      default     = true,
    },
    file = {
      type        = "string",
      name        = "File filter",
      description = "File or pattern to run",
      optional    = true,
    },
    reporter = {
      type        = "enum",
      name        = "Reporter",
      choices     = { "verbose", "dot", "json", "junit" },
      optional    = true,
      default     = "verbose",
    },
  },
  priority = 85,
  tags     = { "node", "vitest", "test" },
  condition = {
    filetype = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    callback = function(_)
      return vim.fs.root(vim.fn.expand("%:p:h"), { "vitest.config.ts", "vitest.config.js" }) ~= nil
    end,
  },
}
