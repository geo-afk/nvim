-- debugger.lua — Neovim Go debugger core (Delve DAP, Neovim 0.11+)
local M = {}

local ui = require("custom.go.debugger_ui")

-- ─── shared state ─────────────────────────────────────────────────────────────

local state = {
  breakpoints = {}, -- [key] = { file, line, condition }
  session = nil, -- active Session
  synced_bp_files = {}, -- files whose BPs have been sent to dlv
}

-- ─── utility ──────────────────────────────────────────────────────────────────

local function notify(msg, level)
  vim.schedule(function()
    vim.notify("[go-debug] " .. msg, level or vim.log.levels.INFO)
  end)
end

local function normalize_path(path)
  return vim.fn.fnamemodify(path, ":p"):gsub("\\", "/")
end

local function bp_key(file, line)
  return string.format("%s:%d", normalize_path(file), line)
end

local function ensure_dlv()
  if vim.fn.executable("dlv") == 0 then
    notify("dlv not found. Install: go install github.com/go-delve/delve/cmd/dlv@latest", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function assert_go_file()
  local f = vim.fn.expand("%:p")
  if f == "" or not f:match("%.go$") then
    notify("not a Go file", vim.log.levels.WARN)
    return nil
  end
  return f
end

-- ─── breakpoints helpers ──────────────────────────────────────────────────────

local function sorted_breakpoints()
  local items = {}
  for _, bp in pairs(state.breakpoints) do
    table.insert(items, vim.deepcopy(bp))
  end
  table.sort(items, function(a, b)
    local af, bf = normalize_path(a.file), normalize_path(b.file)
    return af == bf and a.line < b.line or af < bf
  end)
  return items
end

local function grouped_breakpoints()
  local grouped = {}
  for _, bp in pairs(state.breakpoints) do
    local f = normalize_path(bp.file)
    grouped[f] = grouped[f] or {}
    table.insert(grouped[f], bp)
  end
  return grouped
end

local function refresh_bp_signs()
  ui.render_breakpoint_signs(sorted_breakpoints())
end

local function render_breakpoints()
  ui.render_breakpoints(sorted_breakpoints())
end

-- ─── project helpers ──────────────────────────────────────────────────────────

local function project_root(start)
  start = start or vim.fn.expand("%:p:h")
  local found = vim.fs.find({ "go.work", "go.mod", ".git" }, { upward = true, path = start })[1]
  return found and vim.fs.dirname(found) or vim.fn.getcwd()
end

local function go_package_dir()
  local f = assert_go_file()
  return f and vim.fn.fnamemodify(f, ":h") or vim.fn.getcwd()
end

local function current_package_name()
  local n = math.min(vim.api.nvim_buf_line_count(0), 80)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, n, false)) do
    local pkg = line:match("^%s*package%s+([%w_]+)")
    if pkg then
      return pkg
    end
  end
  return nil
end

local function find_main_package()
  local f = assert_go_file()
  local fdir = f and vim.fn.fnamemodify(f, ":h") or vim.fn.getcwd()
  if f and current_package_name() == "main" then
    return fdir
  end
  local root = project_root(fdir)
  local candidates = {
    root .. "/main.go",
    root .. "/cmd/main.go",
  }
  for _, c in ipairs(candidates) do
    if vim.fn.filereadable(c) == 1 then
      return vim.fn.fnamemodify(c, ":h")
    end
  end
  local matches = vim.fn.glob(root .. "/cmd/*/main.go", false, true)
  if #matches > 0 then
    return vim.fn.fnamemodify(matches[1], ":h")
  end
  return root
end

local function binary_name(program)
  local name = vim.fn.fnamemodify(program, ":t")
  if name == "" or name == "." then
    name = vim.fn.fnamemodify(project_root(program), ":t")
  end
  if vim.uv.os_uname().sysname:find("Windows") and not name:match("%.exe$") then
    name = name .. ".exe"
  end
  return name
end

-- ─── Session ──────────────────────────────────────────────────────────────────
-- Wraps a single Delve DAP connection.  One instance per debug run.

local Session = {}
Session.__index = Session

function Session.new()
  return setmetatable({
    seq = 1,
    callbacks = {},
    buffer = "",
    client = nil,
    handle = nil,
    stdout = nil,
    stderr = nil,
    closed = false,

    initialized = false,
    configured = false,
    bp_sent_early = false, -- BPs were synced before launch request
    stopped_tid = nil,
    current_fid = nil, -- current frame id for evaluate
    connected = false,
  }, Session)
end

-- low-level write
function Session:send(msg)
  if not self.client or self.closed then
    return
  end
  local encoded = vim.json.encode(msg)
  local packet = string.format("Content-Length: %d\r\n\r\n%s", #encoded, encoded)
  self.client:write(packet)
end

-- send a DAP request; callback(response) called on vim main thread
function Session:request(command, args, callback)
  if self.closed then
    return
  end
  local seq = self.seq
  self.seq = self.seq + 1
  self.callbacks[seq] = callback -- may be nil
  self:send({
    seq = seq,
    type = "request",
    command = command,
    arguments = args or {},
  })
  return seq
end

-- ── DAP protocol parsing ─────────────────────────────────────────────────────

function Session:consume(data)
  self.buffer = self.buffer .. data
  while true do
    local hend = self.buffer:find("\r\n\r\n", 1, true)
    if not hend then
      break
    end
    local header = self.buffer:sub(1, hend - 1)
    local len = tonumber(header:match("[Cc]ontent%-[Ll]ength:%s*(%d+)"))
    if not len then
      -- corrupt stream — reset
      self.buffer = ""
      break
    end
    local body_start = hend + 4
    local body_end = body_start + len - 1
    if #self.buffer < body_end then
      break
    end
    local body = self.buffer:sub(body_start, body_end)
    self.buffer = self.buffer:sub(body_end + 1)
    local ok, msg = pcall(vim.json.decode, body)
    if ok then
      self:dispatch(msg)
    else
      ui.append_output("[DAP parse error] " .. tostring(msg))
    end
  end
end

function Session:dispatch(msg)
  if msg.type == "response" then
    local cb = self.callbacks[msg.request_seq]
    self.callbacks[msg.request_seq] = nil
    if cb then
      vim.schedule(function()
        cb(msg)
      end)
    elseif not msg.success then
      local text = msg.message or "DAP error (no message)"
      -- surface error detail from body if present
      if msg.body and msg.body.error and msg.body.error.format then
        text = text .. ": " .. msg.body.error.format
      end
      ui.append_output("[DAP error] " .. text)
    end
  elseif msg.type == "event" then
    vim.schedule(function()
      self:handle_event(msg)
    end)
  end
end

-- ── DAP events ───────────────────────────────────────────────────────────────

function Session:handle_event(msg)
  local ev = msg.event
  if ev == "initialized" then
    ui.append_output("● dlv initialized")
    self:on_initialized()
  elseif ev == "stopped" then
    local reason = msg.body and msg.body.reason or "stopped"
    ui.append_output("⏸  " .. reason)
    self:refresh_stopped(msg)
  elseif ev == "continued" then
    ui.append_output("▶ running")
    ui.clear_execution_line()
    ui.render_stack({})
    ui.render_variables({}, {})
  elseif ev == "output" then
    local body = msg.body or {}
    local text = body.output or ""
    if text ~= "" then
      ui.append_output(text)
    end
  elseif ev == "terminated" then
    ui.append_output("■ process terminated")
    ui.clear_execution_line()
  elseif ev == "exited" then
    local code = msg.body and msg.body.exitCode
    ui.append_output("■ exited" .. (code ~= nil and (" (code " .. tostring(code) .. ")") or ""))
    ui.clear_execution_line()
  elseif ev == "process" then
    local body = msg.body or {}
    ui.append_output(string.format("process %s (pid %s)", body.name or "?", tostring(body.systemProcessId or "?")))
  end
end

-- called after "initialized" event
function Session:on_initialized()
  self.initialized = true
  if self.bp_sent_early then
    -- BPs already sent; just call configurationDone
    self:request("configurationDone", {}, function(r)
      if r.success then
        self.configured = true
        ui.append_output("● configuration done")
      else
        ui.append_output("[warn] configurationDone: " .. tostring(r.message))
      end
    end)
  else
    self:sync_breakpoints(function()
      self:request("configurationDone", {}, function(r)
        if r.success then
          self.configured = true
          ui.append_output("● configuration done")
        else
          ui.append_output("[warn] configurationDone: " .. tostring(r.message))
        end
      end)
    end)
  end
end

-- ── Breakpoint sync ───────────────────────────────────────────────────────────
-- Sends setBreakpoints for every file that has (or had) BPs.
-- Calls done() when all requests complete.

function Session:sync_breakpoints(done)
  if self.closed then
    if done then
      done()
    end
    return
  end

  local grouped = grouped_breakpoints()
  -- union of current files and previously synced files (to clear removed BPs)
  local file_set = {}
  for f in pairs(grouped) do
    file_set[f] = true
  end
  for f in pairs(state.synced_bp_files) do
    file_set[f] = true
  end

  local files = vim.tbl_keys(file_set)
  local remaining = #files

  if remaining == 0 then
    if done then
      done()
    end
    return
  end

  for _, file in ipairs(files) do
    local bps_for_file = grouped[file] or {}
    local source = { path = file, name = vim.fn.fnamemodify(file, ":t") }
    local dap_bps = vim.tbl_map(function(bp)
      local entry = { line = bp.line }
      if bp.condition and bp.condition ~= "" then
        entry.condition = bp.condition
      end
      return entry
    end, bps_for_file)

    self:request("setBreakpoints", {
      source = source,
      breakpoints = dap_bps,
      lines = vim.tbl_map(function(bp)
        return bp.line
      end, bps_for_file),
      sourceModified = false,
    }, function(resp)
      if resp.success then
        if #dap_bps == 0 then
          state.synced_bp_files[file] = nil
        else
          state.synced_bp_files[file] = true
          -- report verified BPs
          local verified = 0
          if resp.body and resp.body.breakpoints then
            for _, b in ipairs(resp.body.breakpoints) do
              if b.verified then
                verified = verified + 1
              end
            end
          end
          ui.append_output(
            string.format("  %d/%d BP verified in %s", verified, #dap_bps, vim.fn.fnamemodify(file, ":~:."))
          )
        end
      else
        ui.append_output(
          "[warn] setBreakpoints failed for " .. vim.fn.fnamemodify(file, ":~:.") .. ": " .. tostring(resp.message)
        )
      end
      remaining = remaining - 1
      if remaining == 0 and done then
        done()
      end
    end)
  end
end

-- ── Stopped state refresh ─────────────────────────────────────────────────────

function Session:refresh_stopped(event)
  local tid = (event.body and event.body.threadId) or self.stopped_tid or 1
  self.stopped_tid = tid

  self:request("stackTrace", {
    threadId = tid,
    startFrame = 0,
    levels = 20,
  }, function(resp)
    local frames = resp.body and resp.body.stackFrames or {}
    ui.render_stack(frames)
    local top = frames[1]
    self.current_fid = top and top.id or nil

    if top and top.source and top.source.path and top.line then
      local reason = event.body and event.body.reason or "stopped"
      ui.show_execution_line(top.source.path, top.line, reason)
    end

    if not top then
      ui.render_variables({}, {})
      return
    end

    self:request("scopes", { frameId = top.id }, function(sresp)
      local scopes = sresp.body and sresp.body.scopes or {}
      if #scopes == 0 then
        ui.render_variables({}, {})
        return
      end

      local vars_by_scope = {}
      local pending = #scopes

      for _, scope in ipairs(scopes) do
        self:request("variables", {
          variablesReference = scope.variablesReference,
          count = 200,
        }, function(vresp)
          vars_by_scope[scope.variablesReference] = vresp.body and vresp.body.variables or {}
          pending = pending - 1
          if pending == 0 then
            ui.render_variables(scopes, vars_by_scope)
          end
        end)
      end
    end)
  end)
end

-- ── TCP connection ────────────────────────────────────────────────────────────

function Session:connect(host, port, callback)
  local tcp = vim.uv.new_tcp()
  self.client = tcp

  tcp:connect(host, port, function(err)
    if err then
      notify("failed to connect to Delve DAP: " .. err, vim.log.levels.ERROR)
      return
    end
    self.connected = true
    tcp:read_start(function(rerr, data)
      if rerr then
        if not self.closed then
          ui.append_output("[DAP read error] " .. rerr)
        end
        return
      end
      if data then
        self:consume(data)
      else
        -- EOF — connection closed
        if not self.closed then
          ui.append_output("● DAP connection closed")
        end
      end
    end)
    if callback then
      vim.schedule(callback)
    end
  end)
end

-- ── Teardown ─────────────────────────────────────────────────────────────────

function Session:close()
  if self.closed then
    return
  end
  self.closed = true
  -- cancel pending callbacks
  for seq, cb in pairs(self.callbacks) do
    self.callbacks[seq] = nil
    if cb then
      vim.schedule(function()
        cb({ success = false, message = "session closed" })
      end)
    end
  end
  local function safe_close(h)
    if h and not h:is_closing() then
      h:close()
    end
  end
  safe_close(self.client)
  safe_close(self.stdout)
  safe_close(self.stderr)
  if self.handle and not self.handle:is_closing() then
    self.handle:kill("sigterm")
    vim.defer_fn(function()
      safe_close(self.handle)
    end, 500)
  end
end

-- ─── process spawning ─────────────────────────────────────────────────────────

local function close_session()
  if state.session then
    state.session:close()
    state.session = nil
  end
end

-- Spawn `dlv dap --listen 127.0.0.1:0`, parse the actual port from stdout/stderr,
-- then call on_listen(host, port).
local function launch_dlv_dap(session, cwd, on_listen)
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)
  session.stdout = stdout
  session.stderr = stderr

  local handle
  handle = vim.uv.spawn("dlv", {
    args = { "dap", "--listen", "127.0.0.1:0", "--log-output", "dap", "--log" },
    stdio = { nil, stdout, stderr },
    cwd = cwd,
  }, function(code)
    session.closed = true
    vim.schedule(function()
      if code ~= 0 then
        ui.append_output("dlv exited with code " .. tostring(code))
      end
    end)
  end)

  if not handle then
    notify("failed to spawn dlv dap", vim.log.levels.ERROR)
    return false
  end
  session.handle = handle

  -- Shared logic: watch output lines for the "listening at" line.
  -- dlv prints to stderr by default; listen on both to be safe.
  local function watch(data)
    if not data or data == "" then
      return
    end
    vim.schedule(function()
      for _, line in ipairs(vim.split(data, "\n", { plain = true, trimempty = true })) do
        ui.append_output(line)
      end
    end)
    -- Pattern: "DAP server listening at: 127.0.0.1:PORT"
    if not session.connected then
      local host, port = data:match("DAP server listening at:%s*([%d%.]+):(%d+)")
      if not host then
        -- older dlv just prints the port
        port = data:match("DAP server listening at:%s*:(%d+)")
        host = port and "127.0.0.1" or nil
      end
      if host and port then
        session.connected = true
        on_listen(host, tonumber(port))
      end
    end
  end

  stdout:read_start(function(_, d)
    watch(d)
  end)
  stderr:read_start(function(_, d)
    watch(d)
  end)
  return true
end

-- ─── session start ────────────────────────────────────────────────────────────

local function start_session(config, opts)
  opts = opts or {}
  if not ensure_dlv() then
    return
  end

  ui.open()
  render_breakpoints()
  ui.clear_execution_line()
  close_session()

  local session = Session.new()
  state.session = session

  local dap_cwd = opts.dap_cwd or config.cwd or vim.fn.getcwd()
  ui.append_output("starting dlv dap in: " .. vim.fn.fnamemodify(dap_cwd, ":~:."))

  local ok = launch_dlv_dap(session, dap_cwd, function(host, port)
    ui.append_output(string.format("connecting to dlv at %s:%d", host, port))
    session:connect(host, port, function()
      ui.append_output("connected")
      session:request("initialize", {
        clientID = "nvim",
        clientName = "Neovim",
        adapterID = "go",
        pathFormat = "path",
        linesStartAt1 = true,
        columnsStartAt1 = true,
        supportsVariableType = true,
        supportsVariablePaging = true,
        supportsRunInTerminalRequest = false,
        supportsProgressReporting = false,
        -- dlv-specific: allow stepping into vendor/std
        supportsDelayedStackTraceLoading = false,
      }, function(init_resp)
        if not init_resp.success then
          ui.append_output("[error] initialize: " .. tostring(init_resp.message))
          return
        end

        -- Send all breakpoints BEFORE launch so they are verified correctly.
        session:sync_breakpoints(function()
          session.bp_sent_early = true
          local launch_cmd = (config.request == "attach") and "attach" or "launch"
          session:request(launch_cmd, config, function(lresp)
            if lresp.success then
              ui.append_output(
                "● " .. launch_cmd .. " accepted: " .. tostring(config.program or config.processId or "target")
              )
            else
              local msg = tostring(lresp.message or "failed")
              if lresp.body and lresp.body.error and lresp.body.error.format then
                msg = msg .. "\n  " .. lresp.body.error.format
              end
              ui.append_output("[error] " .. launch_cmd .. ": " .. msg)
            end
          end)
        end)
      end)
    end)
  end)

  if not ok then
    state.session = nil
  end
end

-- ─── public: launch modes ─────────────────────────────────────────────────────

function M.debug()
  local program = find_main_package()
  local root = project_root(program)
  start_session({
    name = "Debug",
    type = "go",
    request = "launch",
    mode = "debug",
    program = program,
    cwd = root,
    stopOnEntry = true,
    stackTraceDepth = 50,
    hideSystemGoroutines = true,
  }, { dap_cwd = root })
end

function M.test()
  local program = go_package_dir()
  local root = project_root(program)
  start_session({
    name = "Test",
    type = "go",
    request = "launch",
    mode = "test",
    program = program,
    cwd = root,
    stopOnEntry = true,
    stackTraceDepth = 50,
    hideSystemGoroutines = true,
  }, { dap_cwd = root })
end

function M.attach(target)
  target = vim.trim(target or vim.fn.input("PID: "))
  if target == "" then
    return
  end
  if not target:match("^%d+$") then
    notify("attach requires a numeric PID. Use GoDlvConnect for remote.", vim.log.levels.WARN)
    return
  end
  local root = project_root()
  start_session({
    name = "Attach",
    type = "go",
    request = "attach",
    mode = "local",
    processId = tonumber(target),
    cwd = root,
    stopOnEntry = false,
    stackTraceDepth = 50,
    hideSystemGoroutines = true,
  }, { dap_cwd = root })
end

-- Build a debug binary then attach to it via `exec` mode
function M.attach_spawn()
  local program = find_main_package()
  local root = project_root(program)
  local out_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "go-debug")
  vim.fn.mkdir(out_dir, "p")
  local exe = vim.fs.joinpath(out_dir, binary_name(program))

  ui.open()
  ui.append_output("building: " .. vim.fn.fnamemodify(exe, ":~:."))

  vim.system({ "go", "build", "-gcflags=all=-N -l", "-o", exe, "." }, { cwd = program, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local msg = vim.trim((res.stderr ~= "" and res.stderr) or res.stdout)
        ui.append_output("build failed:\n" .. msg)
        notify("build failed", vim.log.levels.ERROR)
        return
      end
      ui.append_output("build OK: " .. vim.fn.fnamemodify(exe, ":~:."))
      start_session({
        name = "Exec",
        type = "go",
        request = "launch",
        mode = "exec",
        program = exe,
        cwd = root,
        stopOnEntry = true,
        stackTraceDepth = 50,
        hideSystemGoroutines = true,
      }, { dap_cwd = root })
    end)
  end)
end

-- Connect to a running headless `dlv dap --headless` server
function M.connect(addr)
  addr = vim.trim(addr or vim.fn.input("host:port: "))
  local host, port = addr:match("^([^:]+):(%d+)$")
  if not host then
    notify("expected host:port", vim.log.levels.WARN)
    return
  end
  ui.open()
  close_session()
  local session = Session.new()
  state.session = session
  session:connect(host, tonumber(port), function()
    ui.append_output(string.format("connected to %s:%s", host, port))
    session:request("initialize", {
      clientID = "nvim",
      clientName = "Neovim",
      adapterID = "go",
      pathFormat = "path",
      linesStartAt1 = true,
      columnsStartAt1 = true,
    }, function(init_resp)
      if not init_resp.success then
        ui.append_output("[error] initialize: " .. tostring(init_resp.message))
        return
      end
      session:sync_breakpoints(function()
        session.bp_sent_early = true
        session:request("attach", { request = "attach", mode = "remote" }, function(r)
          if not r.success then
            ui.append_output("[error] attach: " .. tostring(r.message))
          end
        end)
      end)
    end)
  end)
end

-- ─── public: process discovery ───────────────────────────────────────────────

local function parse_ps_windows(output)
  local list = {}
  for _, line in ipairs(vim.split(output or "", "\n", { plain = true, trimempty = true })) do
    local pid, name, cmd = line:match("^(%d+)\t([^\t]*)\t?(.*)$")
    if pid then
      table.insert(list, {
        pid = tonumber(pid),
        name = name ~= "" and name or "?",
        command = cmd ~= "" and cmd or name,
      })
    end
  end
  table.sort(list, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return list
end

local function discover_processes(callback)
  local is_windows = vim.uv.os_uname().sysname:find("Windows") ~= nil
  local cmd
  if is_windows then
    cmd = {
      "powershell",
      "-NoProfile",
      "-Command",
      "$ErrorActionPreference='SilentlyContinue';"
        .. "Get-CimInstance Win32_Process |"
        .. "Where-Object { $_.ExecutablePath -and ($_.Name -notmatch '^(dlv|go|gopls)(\\.exe)?$') } |"
        .. 'ForEach-Object { "$($_.ProcessId)`t$($_.Name)`t$($_.CommandLine)" }',
    }
  else
    cmd = { "ps", "-axo", "pid=,comm=,args=" }
  end

  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        notify("process discovery failed", vim.log.levels.ERROR)
        return
      end
      local procs
      if is_windows then
        procs = parse_ps_windows(res.stdout)
      else
        procs = {}
        for _, line in ipairs(vim.split(res.stdout or "", "\n", { plain = true, trimempty = true })) do
          local pid, name, command = line:match("^%s*(%d+)%s+(%S+)%s+(.*)$")
          if pid and not name:match("/?dlv$") and not name:match("/?go$") and not name:match("/?gopls$") then
            table.insert(procs, { pid = tonumber(pid), name = name, command = command })
          end
        end
      end
      callback(procs)
    end)
  end)
end

function M.attach_select()
  discover_processes(function(procs)
    if #procs == 0 then
      notify("no attachable processes found", vim.log.levels.WARN)
      return
    end
    vim.ui.select(procs, {
      prompt = "Attach to process:",
      format_item = function(item)
        local cmd = item.command or item.name
        if #cmd > 100 then
          cmd = cmd:sub(1, 97) .. "…"
        end
        return string.format("%d  %s  %s", item.pid, item.name, cmd)
      end,
    }, function(choice)
      if choice then
        M.attach(tostring(choice.pid))
      end
    end)
  end)
end

-- ─── public: breakpoints ─────────────────────────────────────────────────────

local function current_location()
  local f = assert_go_file()
  if not f then
    return nil, nil
  end
  return f, vim.api.nvim_win_get_cursor(0)[1]
end

local function bp_changed()
  refresh_bp_signs()
  render_breakpoints()
  if state.session and state.session.initialized then
    state.session:sync_breakpoints()
  end
end

function M.set_breakpoint(opts)
  local file, line = current_location()
  if not file then
    return
  end
  opts = opts or {}
  state.breakpoints[bp_key(file, line)] = {
    file = normalize_path(file),
    line = line,
    condition = opts.condition,
  }
  bp_changed()
end

function M.remove_breakpoint()
  local file, line = current_location()
  if not file then
    return
  end
  state.breakpoints[bp_key(file, line)] = nil
  bp_changed()
end

function M.toggle_breakpoint()
  local file, line = current_location()
  if not file then
    return
  end
  local key = bp_key(file, line)
  if state.breakpoints[key] then
    state.breakpoints[key] = nil
  else
    state.breakpoints[key] = { file = normalize_path(file), line = line }
  end
  bp_changed()
end

function M.conditional_breakpoint()
  local file, line = current_location()
  if not file then
    return
  end
  local existing = state.breakpoints[bp_key(file, line)]
  local cond = vim.trim(vim.fn.input("Condition: ", existing and existing.condition or ""))
  state.breakpoints[bp_key(file, line)] = {
    file = normalize_path(file),
    line = line,
    condition = cond ~= "" and cond or nil,
  }
  bp_changed()
end

function M.clear_breakpoints()
  state.breakpoints = {}
  bp_changed()
end

function M.list_breakpoints()
  ui.open()
  render_breakpoints()
  return sorted_breakpoints()
end

-- ─── public: execution control ───────────────────────────────────────────────

local function need_session()
  if not state.session or state.session.closed then
    notify("no active debug session", vim.log.levels.WARN)
    return nil
  end
  return state.session
end

local function active_tid()
  local s = need_session()
  return s and (s.stopped_tid or 1) or nil
end

function M.continue()
  local tid = active_tid()
  if tid then
    state.session:request("continue", { threadId = tid, singleThread = false })
  end
end

function M.step_over()
  local tid = active_tid()
  if tid then
    state.session:request("next", { threadId = tid })
  end
end

function M.step_into()
  local tid = active_tid()
  if tid then
    state.session:request("stepIn", { threadId = tid })
  end
end

function M.step_out()
  local tid = active_tid()
  if tid then
    state.session:request("stepOut", { threadId = tid })
  end
end

-- ─── public: inspection ──────────────────────────────────────────────────────

function M.stack()
  local s = need_session()
  if not s then
    return
  end
  s:request("stackTrace", {
    threadId = s.stopped_tid or 1,
    startFrame = 0,
    levels = 50,
  }, function(resp)
    ui.render_stack(resp.body and resp.body.stackFrames or {})
  end)
end

function M.variables()
  local s = need_session()
  if not s then
    return
  end
  s:request("stackTrace", {
    threadId = s.stopped_tid or 1,
    startFrame = 0,
    levels = 1,
  }, function(resp)
    local frame = resp.body and resp.body.stackFrames and resp.body.stackFrames[1]
    if not frame then
      return
    end
    s:request("scopes", { frameId = frame.id }, function(sresp)
      local scopes = sresp.body and sresp.body.scopes or {}
      local vars = {}
      local pending = #scopes
      if pending == 0 then
        ui.render_variables({}, {})
        return
      end
      for _, scope in ipairs(scopes) do
        s:request("variables", {
          variablesReference = scope.variablesReference,
          count = 200,
        }, function(vresp)
          vars[scope.variablesReference] = vresp.body and vresp.body.variables or {}
          pending = pending - 1
          if pending == 0 then
            ui.render_variables(scopes, vars)
          end
        end)
      end
    end)
  end)
end

function M.inspect(expr)
  expr = vim.trim(expr or vim.fn.input("Inspect: ", vim.fn.expand("<cword>")))
  if expr == "" then
    return
  end
  local s = need_session()
  if not s then
    return
  end
  s:request("evaluate", {
    expression = expr,
    context = "repl",
    frameId = s.current_fid,
  }, function(resp)
    if resp.success and resp.body then
      ui.append_output(expr .. " = " .. tostring(resp.body.result))
    else
      ui.append_output("inspect failed: " .. tostring(resp.message))
    end
  end)
end

-- ─── public: stop / ui ───────────────────────────────────────────────────────

function M.stop()
  local s = state.session
  if s then
    s:request("disconnect", { terminateDebuggee = true }, function()
      s:close()
      if state.session == s then
        state.session = nil
      end
      ui.clear_execution_line()
    end)
  end
  -- clear UI regardless
  ui.clear_execution_line()
  ui.render_stack({})
  ui.render_variables({}, {})
end

function M.toggle_ui()
  ui.toggle()
  render_breakpoints()
  return ui.is_open()
end

-- ─── setup ────────────────────────────────────────────────────────────────────

function M.setup()
  ui.setup()
  refresh_bp_signs()

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("GoDebugBPSigns", { clear = true }),
    pattern = "*.go",
    callback = refresh_bp_signs,
  })
end

return M
