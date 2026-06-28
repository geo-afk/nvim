-- =============================================================================
-- lua/overseer/template/node/prettier.lua
-- prettier  – format check or write
-- =============================================================================

return {
  name    = "node: prettier",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), {
      ".prettierrc", ".prettierrc.js", ".prettierrc.json",
      ".prettierrc.yml", "prettier.config.js", "package.json",
    }) or vim.fn.getcwd()

    local target = params.target or "."
    local cmd = { "npx", "--no-install", "prettier" }

    if params.write then
      table.insert(cmd, "--write")
    else
      table.insert(cmd, "--check")
    end

    -- Respect .prettierignore automatically (default behaviour)
    table.insert(cmd, target)

    return {
      name = "prettier " .. (params.write and "--write " or "--check ") .. target,
      cmd  = cmd,
      cwd  = cwd,
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        "on_complete_dispose",
      },
      metadata = { tags = { "node", "prettier" } },
    }
  end,
  params = {
    target = {
      type        = "string",
      name        = "Target",
      description = "File, directory, or glob",
      optional    = true,
      default     = ".",
    },
    write = {
      type        = "boolean",
      name        = "Write",
      description = "Write formatted output (false = check only)",
      optional    = true,
      default     = false,
    },
  },
  priority = 80,
  tags     = { "node", "prettier" },
  condition = {
    filetype = {
      "javascript", "javascriptreact", "typescript", "typescriptreact",
      "json", "html", "css", "scss", "markdown",
    },
  },
}
