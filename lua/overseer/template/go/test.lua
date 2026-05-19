-- =============================================================================
-- lua/overseer/template/go/test.lua
-- go test  ·  go test ./...  ·  go test -race  ·  nearest-file test
-- =============================================================================

--- Shared Go test diagnostics parser (captures test failures + compile errors)
local test_problem_matcher = {
  {
    -- Compile-time errors: file:line:col: message
    pattern = {
      { regexp = "^(.+):(%d+):(%d+): (.+)$",
        file = 1, line = 2, column = 3, message = 4 },
    },
  },
  {
    -- go test -v failure lines: FAIL / --- FAIL
    pattern = {
      { regexp = "^--- FAIL: (.+) %((.+)%)$",
        message = 1 },
    },
  },
}

---@param cwd string
---@param pkg string
---@param extra_args string[]
---@param label string
local function make_test_task(cwd, pkg, extra_args, label)
  local cmd = { "go", "test" }
  vim.list_extend(cmd, extra_args)
  table.insert(cmd, pkg)

  return {
    name = label,
    cmd  = cmd,
    cwd  = cwd,
    env  = {
      -- Coloured output breaks parsing; keep plain text
      TERM = "dumb",
    },
    components = {
      { "display_duration",   detail_level = 2 },
      "on_output_summarize",
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
      { "on_output_parse",    problem_matcher = test_problem_matcher },
      { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
      "on_complete_dispose",
    },
    metadata = { tags = { "go", "test" } },
  }
end

return {
  -- ── go test (current package) ────────────────────────────────────────────
  {
    name    = "go: test (package)",
    builder = function(params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
             or vim.fn.getcwd()
      local extra = { "-v" }
      if params.timeout then
        vim.list_extend(extra, { "-timeout", params.timeout })
      end
      return make_test_task(cwd, params.pkg or ".", extra, "go test " .. (params.pkg or "."))
    end,
    params = {
      pkg = {
        type        = "string",
        name        = "Package",
        description = "Package path (default: .)",
        optional    = true,
        default     = ".",
      },
      timeout = {
        type        = "string",
        name        = "Timeout",
        description = "Test timeout (e.g. 30s, 2m)",
        optional    = true,
        default     = "30s",
      },
    },
    priority = 20,
    tags     = { "go", "test" },
    condition = { filetype = { "go" } },
  },

  -- ── go test ./... ────────────────────────────────────────────────────────
  {
    name    = "go: test all (./...)",
    builder = function(params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
             or vim.fn.getcwd()
      local extra = { "-v" }
      if params.timeout then
        vim.list_extend(extra, { "-timeout", params.timeout })
      end
      return make_test_task(cwd, "./...", extra, "go test ./...")
    end,
    params = {
      timeout = {
        type     = "string",
        name     = "Timeout",
        optional = true,
        default  = "2m",
      },
    },
    priority = 21,
    tags     = { "go", "test" },
    condition = { filetype = { "go" } },
  },

  -- ── go test -race ./... ──────────────────────────────────────────────────
  {
    name    = "go: test -race (./...)",
    builder = function(params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work" })
             or vim.fn.getcwd()
      local extra = { "-race", "-v" }
      if params.timeout then
        vim.list_extend(extra, { "-timeout", params.timeout })
      end
      return make_test_task(cwd, "./...", extra, "go test -race ./...")
    end,
    params = {
      timeout = {
        type     = "string",
        name     = "Timeout",
        optional = true,
        default  = "5m",
      },
    },
    priority = 22,
    tags     = { "go", "test", "race" },
    condition = { filetype = { "go" } },
  },

  -- ── go test – nearest file ───────────────────────────────────────────────
  -- Runs tests in the same package as the currently open file.
  {
    name    = "go: test (nearest file)",
    builder = function(params)
      local filepath = vim.fn.expand("%:p")
      local dir      = vim.fn.fnamemodify(filepath, ":h")
      local cwd      = vim.fs.root(dir, { "go.mod", "go.work" }) or dir

      -- Derive the import path relative to module root so we can target it
      local pkg_path = "."
      local rel = vim.fn.fnamemodify(dir, ":~:.")  -- relative path
      if rel ~= "" and rel ~= "." then
        pkg_path = "./" .. rel:gsub("\\", "/")
      end

      local run_flag = {}
      if params.run and params.run ~= "" then
        vim.list_extend(run_flag, { "-run", params.run })
      end

      local extra = { "-v" }
      vim.list_extend(extra, run_flag)
      return make_test_task(cwd, pkg_path, extra, "go test " .. pkg_path)
    end,
    params = {
      run = {
        type        = "string",
        name        = "Run regex",
        description = "Optional -run filter (e.g. TestFoo)",
        optional    = true,
      },
    },
    priority = 15,
    tags     = { "go", "test", "nearest" },
    condition = { filetype = { "go" } },
  },
}
