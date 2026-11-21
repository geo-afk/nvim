-- lua/dap/cpp.lua
-- C / C++ debug adapter: cpptools (OpenDebugAD7 via Mason or system)

local dap_ok, dap = pcall(require, "dap")
if not dap_ok then
  return
end

local u = require("dap.local_utils")

local function get_cpptools_path()
  local is_windows = package.config:sub(1, 1) == "\\"
  local mason_path = vim.fn.stdpath("data") .. "/mason"

  local candidates = {
    mason_path .. "/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7.exe",
    mason_path .. "/bin/OpenDebugAD7.cmd",
    mason_path .. "/bin/OpenDebugAD7.exe",
    mason_path .. "/bin/OpenDebugAD7",
  }

  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  local default_bin = is_windows and "OpenDebugAD7.exe" or "OpenDebugAD7"
  return u.require_bin(default_bin)
end

-- ---------------------------------------------------------------------------
-- Adapters
-- ---------------------------------------------------------------------------
dap.adapters.cppdbg = {
  id = "cppdbg",
  type = "executable",
  command = get_cpptools_path(),
  options = {
    detached = false,
  },
}

-- Alias for cpptools
dap.adapters.cpptools = dap.adapters.cppdbg

-- ---------------------------------------------------------------------------
-- Configurations
-- ---------------------------------------------------------------------------
local configs = {
  {
    name = "C/C++: Launch executable",
    type = "cppdbg",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopAtEntry = false,
    setupCommands = {
      {
        text = "-enable-pretty-printing",
        description = "enable pretty printing",
        ignoreFailures = false,
      },
    },
  },
  {
    name = "C/C++: Launch with arguments",
    type = "cppdbg",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    args = function()
      local input = vim.fn.input("Arguments: ")
      return vim.split(input, " +", { trimempty = true })
    end,
    cwd = "${workspaceFolder}",
    stopAtEntry = false,
    setupCommands = {
      {
        text = "-enable-pretty-printing",
        description = "enable pretty printing",
        ignoreFailures = false,
      },
    },
  },
  {
    name = "C/C++: Attach to process (PID)",
    type = "cppdbg",
    request = "attach",
    processId = u.pick_pid,
    cwd = "${workspaceFolder}",
  },
  {
    name = "C/C++: Attach to gdbserver",
    type = "cppdbg",
    request = "launch",
    MIMode = "gdb",
    miDebuggerServerAddress = function()
      return vim.fn.input("gdbserver address: ", "localhost:1234")
    end,
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    setupCommands = {
      {
        text = "-enable-pretty-printing",
        description = "enable pretty printing",
        ignoreFailures = false,
      },
    },
  },
}

dap.configurations.c = configs
dap.configurations.cpp = configs
