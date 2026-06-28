-- =============================================================================
-- lua/overseer/template/node/eslint.lua
-- eslint – lint JS/TS files, populate quickfix
-- =============================================================================

return {
  name    = "node: eslint",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), {
      ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json",
      ".eslintrc.yml", "eslint.config.js", "eslint.config.mjs", "package.json",
    }) or vim.fn.getcwd()

    local target = params.target or "."
    local cmd = { "npx", "--no-install", "eslint",
                  "--format", "unix",    -- file:line:col: message [rule]
                  "--max-warnings", "0" }
    if params.fix then table.insert(cmd, "--fix") end
    table.insert(cmd, target)

    return {
      name = "eslint " .. target,
      cmd  = cmd,
      cwd  = cwd,
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        {
          "on_output_parse",
          problem_matcher = {
            {
              -- Unix format:  /path/to/file.ts:10:5: message [rule/name]
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
      metadata = { tags = { "node", "eslint" } },
    }
  end,
  params = {
    target = {
      type        = "string",
      name        = "Target",
      description = "File/dir/glob to lint (default: .)",
      optional    = true,
      default     = ".",
    },
    fix = {
      type     = "boolean",
      name     = "Fix",
      optional = true,
      default  = false,
    },
  },
  priority = 75,
  tags     = { "node", "eslint" },
  condition = {
    filetype = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  },
}
