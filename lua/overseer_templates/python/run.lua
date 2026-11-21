-- =============================================================================
-- lua/overseer_templates/python/run.lua
-- Python runners: run current file or main entrypoint
-- =============================================================================

local detector = require("overseer_templates.detector")

---Find a sensible default main/entrypoint in a Python project
---@param root string
---@return string
local function find_default_entrypoint(root)
  local candidates = {
    "main.py",
    "app.py",
    "run.py",
    "src/main.py",
    "src/app.py",
    "__main__.py",
  }
  for _, rel in ipairs(candidates) do
    local full = root .. "/" .. rel
    if vim.uv.fs_stat(full) then
      return rel
    end
  end
  return "main.py"
end

return {
  -- ── 1. Run current file ────────────────────────────────────────────────────
  {
    name = "python: run current file",
    builder = function(params)
      local buf = vim.api.nvim_buf_get_name(0)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()
      local py_bin = detector.get_python_bin(cwd)

      local target = (params.file and params.file ~= "") and params.file or buf
      if target == "" then
        target = vim.fn.expand("%:p")
      end

      local cmd = { py_bin, target }
      if params.args and params.args ~= "" then
        vim.list_extend(cmd, vim.split(params.args, " ", { plain = true, trimempty = true }))
      end

      local display_name = "python " .. vim.fn.fnamemodify(target, ":t")

      return {
        name = display_name,
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
                  { regexp = '^  File "([^"]+)", line (%d+), in (.+)$', file = 1, line = 2, message = 3 },
                },
              },
            },
          },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "run" } },
      }
    end,
    params = {
      file = {
        type = "string",
        name = "Script file",
        description = "Python file to execute (default: current buffer)",
        optional = true,
      },
      args = {
        type = "string",
        name = "Arguments",
        description = "Arguments to pass to script",
        optional = true,
      },
    },
    priority = 5,
    tags = { "python", "run" },
  },

  -- ── 2. Run main entrypoint ─────────────────────────────────────────────────
  {
    name = "python: run main",
    builder = function(params)
      local _, root = detector.is_python()
      local cwd = root or vim.fn.getcwd()
      local py_bin = detector.get_python_bin(cwd)

      local target = (params.target and params.target ~= "") and params.target or find_default_entrypoint(cwd)

      local cmd = { py_bin }
      if target:match("^%-m%s+") then
        local mod = target:gsub("^%-m%s+", "")
        table.insert(cmd, "-m")
        table.insert(cmd, mod)
      else
        table.insert(cmd, target)
      end

      if params.args and params.args ~= "" then
        vim.list_extend(cmd, vim.split(params.args, " ", { plain = true, trimempty = true }))
      end

      return {
        name = "python " .. target,
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
                  { regexp = '^  File "([^"]+)", line (%d+), in (.+)$', file = 1, line = 2, message = 3 },
                },
              },
            },
          },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = { tags = { "python", "run" } },
      }
    end,
    params = {
      target = {
        type = "string",
        name = "Target",
        description = "Entrypoint script or '-m <module>' (default: auto-detected)",
        optional = true,
      },
      args = {
        type = "string",
        name = "Arguments",
        description = "CLI arguments",
        optional = true,
      },
    },
    priority = 10,
    tags = { "python", "run" },
  },
}
