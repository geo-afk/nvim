-- =============================================================================
-- lua/overseer/template/cpp/run.lua
-- MinGW: build & run or run compiled executable
-- =============================================================================

local function get_compiler(file)
  local ext = vim.fn.fnamemodify(file, ":e"):lower()
  if ext == "c" then
    return "gcc", "-std=c11"
  end
  return "g++", "-std=c++17"
end

return {
  -- ── 1. Build and Run current file ──────────────────────────────────────────
  {
    name = "cpp: build & run (MinGW)",
    builder = function(params)
      local file = vim.fn.expand("%:p")
      local dir = vim.fn.fnamemodify(file, ":h")
      local basename = vim.fn.fnamemodify(file, ":t:r")
      local exe = dir .. "/" .. basename .. ".exe"
      local compiler, default_std = get_compiler(file)
      local flags = (params.flags and params.flags ~= "") and params.flags or (default_std .. " -Wall -Wextra -g")

      local args_suffix = ""
      if params.args and params.args ~= "" then
        args_suffix = " " .. params.args
      end

      local is_windows = package.config:sub(1, 1) == "\\"
      local full_cmd
      if is_windows then
        local norm_file = file:gsub("/", "\\")
        local norm_exe = exe:gsub("/", "\\")
        local compile_step = string.format('%s %s "%s" -o "%s"', compiler, flags, norm_file, norm_exe)
        local run_step = string.format('"%s"%s', norm_exe, args_suffix)
        full_cmd = { "cmd.exe", "/c", string.format("%s && %s", compile_step, run_step) }
      else
        local compile_step = string.format('%s %s "%s" -o "%s"', compiler, flags, file, exe)
        local run_step = string.format('"%s"%s', exe, args_suffix)
        full_cmd = { "sh", "-c", string.format("%s && %s", compile_step, run_step) }
      end

      return {
        name = string.format("%s run %s", compiler, basename),
        cmd = full_cmd,
        cwd = dir,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          { "on_output_parse", problem_matcher = "$gcc" },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
        },
        metadata = {
          tags = { "cpp", "c", "run", "mingw" },
        },
      }
    end,
    params = {
      args = {
        type = "string",
        name = "Arguments",
        description = "CLI arguments to pass to the executable",
        optional = true,
      },
      flags = {
        type = "string",
        name = "Compiler flags",
        description = "Override compiler flags (e.g. -std=c++20 -O2)",
        optional = true,
      },
    },
    priority = 5,
    tags = { "cpp", "c", "run", "mingw" },
    condition = {
      filetype = { "c", "cpp" },
      callback = function(_)
        return vim.fn.executable("g++") == 1 or vim.fn.executable("gcc") == 1
      end,
    },
  },

  -- ── 2. Run already built executable ────────────────────────────────────────
  {
    name = "cpp: run executable (MinGW)",
    builder = function(params)
      local file = vim.fn.expand("%:p")
      local dir = vim.fn.fnamemodify(file, ":h")
      local basename = vim.fn.fnamemodify(file, ":t:r")
      local default_exe = dir .. "/" .. basename .. ".exe"
      local target = (params.target and params.target ~= "") and params.target or default_exe

      local cmd = { target }
      if params.args and params.args ~= "" then
        vim.list_extend(cmd, vim.split(params.args, " ", { plain = true, trimempty = true }))
      end

      return {
        name = "run " .. vim.fn.fnamemodify(target, ":t"),
        cmd = cmd,
        cwd = dir,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
        },
        metadata = {
          tags = { "cpp", "c", "run", "mingw" },
        },
      }
    end,
    params = {
      target = {
        type = "string",
        name = "Executable",
        description = "Path to executable (default: <filename>.exe)",
        optional = true,
      },
      args = {
        type = "string",
        name = "Arguments",
        description = "CLI arguments",
        optional = true,
      },
    },
    priority = 6,
    tags = { "cpp", "c", "run", "mingw" },
    condition = {
      filetype = { "c", "cpp" },
    },
  },
}
