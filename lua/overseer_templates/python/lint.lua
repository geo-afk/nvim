-- =============================================================================
-- lua/overseer_templates/python/lint.lua
-- Python lint & format (ruff)
-- =============================================================================

local detector = require("overseer_templates.detector")

return {
  -- ── 1. Ruff check (linter) ────────────────────────────────────────────────
  {
    name = "python: ruff check",
    builder = function(_params)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()

      return {
        name = "ruff check",
        cmd = { "ruff", "check", "." },
        cwd = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          {
            "on_output_parse",
            problem_matcher = {
              {
                pattern = {
                  { regexp = "^([^:]+):(%d+):(%d+):%s*(.+)$", file = 1, line = 2, column = 3, message = 4 },
                },
              },
            },
          },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "lint" } },
      }
    end,
    priority = 30,
    tags = { "python", "lint" },
    condition = {
      callback = function(_)
        return vim.fn.executable("ruff") == 1
      end,
    },
  },

  -- ── 2. Ruff format ────────────────────────────────────────────────────────
  {
    name = "python: ruff format",
    builder = function(_params)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()

      return {
        name = "ruff format",
        cmd = { "ruff", "format", "." },
        cwd = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "format" } },
      }
    end,
    priority = 35,
    tags = { "python", "format" },
    condition = {
      callback = function(_)
        return vim.fn.executable("ruff") == 1
      end,
    },
  },
}
