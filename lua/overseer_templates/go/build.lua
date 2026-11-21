-- =============================================================================
-- lua/overseer/template/go/build.lua
-- go build  ·  go build ./...
-- =============================================================================

---@param cwd string
---@return string   compiler name used by errorformat
local function go_errorformat()
  -- Standard Go compiler error format understood by :compiler go
  return table.concat({
    "%A%f:%l:%c: %m",
    "%A%f:%l: %m",
    "%C%*\\s%m",
    "%-G%.%#",
  }, ",")
end

return {
  -- ── go build (current package) ──────────────────────────────────────────
  {
    name         = "go: build",
    builder      = function(params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
             or vim.fn.getcwd()
      return {
        name = "go build " .. (params.pkg or "."),
        cmd  = { "go", "build", params.pkg or "." },
        cwd  = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify",    system = "unfocused" },
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
          { "on_output_quickfix",    open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "go", "build" } },
      }
    end,
    params = {
      pkg = {
        type        = "string",
        name        = "Package",
        description = "Package path to build (default: .)",
        optional    = true,
        default     = ".",
      },
    },
    priority = 10,
    tags     = { "go", "build" },
    condition = {
      filetype = { "go" },
      callback = function(_)
        return vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" }) ~= nil
      end,
    },
  },

  -- ── go build ./... (all packages) ───────────────────────────────────────
  {
    name    = "go: build all (./...)",
    builder = function(_params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
             or vim.fn.getcwd()
      return {
        name = "go build ./...",
        cmd  = { "go", "build", "./..." },
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
        metadata = { tags = { "go", "build" } },
      }
    end,
    params   = {},
    priority = 11,
    tags     = { "go", "build" },
    condition = {
      filetype = { "go" },
      callback = function(_)
        return vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" }) ~= nil
      end,
    },
  },
}
