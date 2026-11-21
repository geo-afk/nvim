-- =============================================================================
-- lua/overseer/template/cpp/build.lua
-- MinGW: gcc / g++ compile current file or project
-- =============================================================================

local function get_compiler(file)
  local ext = vim.fn.fnamemodify(file, ":e"):lower()
  if ext == "c" then
    return "gcc", "-std=c11"
  end
  return "g++", "-std=c++17"
end

return {
  {
    name = "cpp: build (MinGW)",
    builder = function(params)
      local file = vim.fn.expand("%:p")
      if file == "" then
        file = params.file or ""
      end
      local dir = vim.fn.fnamemodify(file, ":h")
      local basename = vim.fn.fnamemodify(file, ":t:r")
      local default_exe = dir .. "/" .. basename .. ".exe"
      local out = (params.output and params.output ~= "") and params.output or default_exe

      local compiler, default_std = get_compiler(file)
      local flags = (params.flags and params.flags ~= "") and params.flags or (default_std .. " -Wall -Wextra -g")

      local cmd = { compiler }
      vim.list_extend(cmd, vim.split(flags, " ", { plain = true, trimempty = true }))
      table.insert(cmd, file)
      table.insert(cmd, "-o")
      table.insert(cmd, out)

      return {
        name = string.format("%s build %s", compiler, basename),
        cmd = cmd,
        cwd = dir,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          { "on_output_parse", problem_matcher = "$gcc" },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = {
          tags = { "cpp", "c", "build", "mingw" },
          output_exe = out,
        },
      }
    end,
    params = {
      flags = {
        type = "string",
        name = "Compiler flags",
        description = "Additional flags (e.g. -std=c++20 -O2 -Iinclude)",
        optional = true,
      },
      output = {
        type = "string",
        name = "Output binary",
        description = "Output executable path (default: <filename>.exe)",
        optional = true,
      },
    },
    priority = 10,
    tags = { "cpp", "c", "build", "mingw" },
    condition = {
      filetype = { "c", "cpp" },
      callback = function(_)
        return vim.fn.executable("g++") == 1 or vim.fn.executable("gcc") == 1
      end,
    },
  },
}
