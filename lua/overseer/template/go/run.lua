-- =============================================================================
-- lua/overseer/template/go/run.lua
-- go run  ·  nearest main.go  or  ./cmd/<name>
-- =============================================================================

return {
  name    = "go: run",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
           or vim.fn.getcwd()

    -- Determine what to run:  explicit target > ./cmd/<dir> > current file
    local target = params.target
    if not target or target == "" then
      -- Auto-detect a cmd/ sub-directory
      local cmd_dir = cwd .. "/cmd"
      if vim.fn.isdirectory(cmd_dir) == 1 then
        local entries = vim.fn.glob(cmd_dir .. "/*", false, true)
        if #entries == 1 then
          target = "./cmd/" .. vim.fn.fnamemodify(entries[1], ":t")
        else
          target = "./..."
        end
      else
        -- Fall back to current file
        target = vim.fn.expand("%:p")
      end
    end

    local cmd = { "go", "run", target }
    if params.args and params.args ~= "" then
      vim.list_extend(cmd, vim.split(params.args, " ", { plain = true }))
    end

    return {
      name = "go run " .. target,
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
      metadata = { tags = { "go", "run" } },
    }
  end,
  params = {
    target = {
      type        = "string",
      name        = "Target",
      description = "Package or file to run (default: auto-detect)",
      optional    = true,
    },
    args = {
      type        = "string",
      name        = "Arguments",
      description = "Extra CLI arguments",
      optional    = true,
    },
  },
  priority = 5,
  tags     = { "go", "run" },
  condition = {
    filetype = { "go" },
    callback = function(_)
      return vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" }) ~= nil
    end,
  },
}
