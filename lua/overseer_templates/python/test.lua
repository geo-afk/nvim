-- =============================================================================
-- lua/overseer_templates/python/test.lua
-- Python test runner: pytest integration
-- =============================================================================

local detector = require("overseer_templates.detector")

return {
  -- ── 1. Run all tests ───────────────────────────────────────────────────────
  {
    name = "python: test (pytest)",
    builder = function(params)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()
      local py_bin = detector.get_python_bin(cwd)

      local cmd = { py_bin, "-m", "pytest" }
      local args_str = params.args or "-v"
      if args_str ~= "" then
        vim.list_extend(cmd, vim.split(args_str, " ", { plain = true, trimempty = true }))
      end

      return {
        name = "pytest " .. args_str,
        cmd = cmd,
        cwd = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          {
            "on_output_parse",
            problem_matcher = {
              {
                pattern = {
                  { regexp = "^FAILED ([^:]+)::(%w+)%s*-%s*(.+)$", file = 1, message = 3 },
                },
              },
            },
          },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "test" } },
      }
    end,
    params = {
      args = {
        type = "string",
        name = "Arguments",
        description = "pytest flags (e.g. -v -k test_foo -x)",
        optional = true,
        default = "-v",
      },
    },
    priority = 20,
    tags = { "python", "test" },
  },

  -- ── 2. Run tests in current file ───────────────────────────────────────────
  {
    name = "python: test current file",
    builder = function(params)
      local buf = vim.api.nvim_buf_get_name(0)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()
      local py_bin = detector.get_python_bin(cwd)

      local file = buf
      if file == "" then
        file = vim.fn.expand("%:p")
      end

      local cmd = { py_bin, "-m", "pytest", file }
      if params.args and params.args ~= "" then
        vim.list_extend(cmd, vim.split(params.args, " ", { plain = true, trimempty = true }))
      end

      return {
        name = "pytest " .. vim.fn.fnamemodify(file, ":t"),
        cmd = cmd,
        cwd = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "test" } },
      }
    end,
    params = {
      args = {
        type = "string",
        name = "Arguments",
        description = "Additional flags (e.g. -s -v)",
        optional = true,
      },
    },
    priority = 25,
    tags = { "python", "test" },
  },
}
