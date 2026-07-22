-- lua/dap/go.lua
-- Go debug adapter: Delve via nvim-dap-go (preferred) or raw dlv fallback.
-- Prerequisite: go install github.com/go-delve/delve/cmd/dlv@latest

local dap_ok, dap = pcall(require, "dap")
if not dap_ok then return end

local u = require("dap.local_utils")

-- ---------------------------------------------------------------------------
-- nvim-dap-go (high-level wrapper)
-- ---------------------------------------------------------------------------
local dapgo_ok, dapgo = pcall(require, "dap-go")
if dapgo_ok then
  dapgo.setup({
    delve = {
      path                    = u.require_bin("dlv"),
      initialize_timeout_sec  = 20,
      port                    = "${port}",
      args                    = {},
      build_flags             = "",
      detect_gopath           = true,
    },
    tests = { verbose = true },
  })

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
  end
  map("<leader>dgt", dapgo.debug_test,      "DAP Go: Debug nearest test")
  map("<leader>dgl", dapgo.debug_last_test, "DAP Go: Debug last test")
  return
end

-- ---------------------------------------------------------------------------
-- Fallback: raw Delve adapter
-- ---------------------------------------------------------------------------
dap.adapters.go = function(callback, config)
  if config.mode == "remote" then
    callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 2345 })
    return
  end

  local uv = vim.uv
  local port   = config.port or math.random(38000, 39000)
  local stdout = uv.new_pipe(false)
  local handle
  local connected = false

  handle = uv.spawn("dlv", {
    stdio = { nil, stdout },
    args  = { "dap", "-l", ("127.0.0.1:%d"):format(port) },
    detached = false,
  }, function(code)
    if stdout and not stdout:is_closing() then stdout:close() end
    if handle and not handle:is_closing() then handle:close() end
    if code ~= 0 then
      vim.notify(("[dap/go] dlv exited code %d"):format(code), vim.log.levels.ERROR)
    end
  end)

  if not handle then
    vim.notify("[dap/go] Failed to spawn dlv", vim.log.levels.ERROR)
    return
  end

  stdout:read_start(function(err, chunk)
    assert(not err, err)
    if not connected and chunk and chunk:match("DAP server listening") then
      connected = true
      callback({ type = "server", host = "127.0.0.1", port = port })
    end
  end)
end

dap.adapters["go-remote"] = {
  type = "server",
  host = "127.0.0.1",
  port = 2345,
}

-- ---------------------------------------------------------------------------
-- Configurations
-- ---------------------------------------------------------------------------
dap.configurations.go = {
  {
    type    = "go",
    name    = "Go: Debug package",
    request = "launch",
    program = "${fileDirname}",
  },
  {
    type    = "go",
    name    = "Go: Debug file",
    request = "launch",
    program = "${file}",
  },
  {
    type    = "go",
    name    = "Go: Debug with args",
    request = "launch",
    program = "${fileDirname}",
    args    = function()
      return vim.split(vim.fn.input("Args: "), " ", { plain = true })
    end,
  },
  {
    type    = "go",
    name    = "Go: Debug cmd/ entry",
    request = "launch",
    program = function()
      local cwd     = u.root({ "go.mod", "go.work" })
      local cmd_dir = cwd .. "/cmd"
      if vim.fn.isdirectory(cmd_dir) == 0 then
        return vim.fn.input("Package path: ", cwd .. "/")
      end
      local entries = vim.fn.glob(cmd_dir .. "/*", false, true)
      if #entries == 1 then return entries[1] end
      return vim.fn.input("Package path: ", cmd_dir .. "/")
    end,
  },
  {
    type    = "go",
    name    = "Go: Debug test (nearest)",
    request = "launch",
    mode    = "test",
    program = "${fileDirname}",
    args    = function()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      local buf = vim.api.nvim_get_current_buf()
      local node = vim.treesitter.get_node({ bufnr = buf, pos = { row, 0 } })
      while node do
        if node:type() == "function_declaration" then
          local nn = node:child(1)
          if nn then
            local fname = vim.treesitter.get_node_text(nn, buf)
            if fname:match("^Test") or fname:match("^Benchmark") then
              return { "-test.run", "^" .. fname .. "$" }
            end
          end
        end
        node = node:parent()
      end
      return { "-test.run", vim.fn.input("Test name: ") }
    end,
  },
  {
    type    = "go",
    name    = "Go: Debug all tests",
    request = "launch",
    mode    = "test",
    program = "${fileDirname}",
  },
  {
    type      = "go",
    name      = "Go: Attach (PID)",
    request   = "attach",
    mode      = "local",
    processId = u.pick_pid,
  },
  {
    type    = "go-remote",
    name    = "Go: Remote attach",
    request = "attach",
    mode    = "remote",
    host    = "127.0.0.1",
    port    = function() return u.pick_port("Remote port", 2345) end,
  },
  {
    type    = "go",
    name    = "Go: Remote Docker/WSL",
    request = "attach",
    mode    = "remote",
    host    = function() return vim.fn.input("Host: ", "127.0.0.1") end,
    port    = function() return u.pick_port("Port", 2345) end,
    substitutePath = {
      {
        from = function() return vim.fn.input("Remote prefix: ", "/app") end,
        to   = function() return u.root({ "go.mod", "go.work" }) end,
      },
    },
  },
}
