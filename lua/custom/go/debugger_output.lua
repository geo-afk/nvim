-- debugger_output.lua - friendly streaming formatter for Delve/DAP output.

local M = {}

local state = {
  skip_block = nil,
  block_depth = 0,
  last_signature = nil,
  repeat_count = 0,
}

local noisy_requests = {
  configurationDone = true,
  continue = true,
  initialize = true,
  scopes = true,
  setBreakpoints = true,
  setExceptionBreakpoints = true,
  stackTrace = true,
  variables = true,
}

local noisy_responses = {
  configurationDone = true,
  continue = true,
  initialize = true,
  scopes = true,
  setExceptionBreakpoints = true,
  variables = true,
}

local function entry(kind, text, raw)
  return {
    kind = kind,
    text = text,
    raw = raw,
  }
end

local function short_path(path)
  path = tostring(path or "")
  if path == "" then
    return "?"
  end
  return vim.fn.fnamemodify(path:gsub("\\", "/"), ":~:.")
end

local function json_decode(payload)
  local ok, decoded = pcall(vim.json.decode, payload)
  if ok then
    return decoded
  end
  return nil
end

local function brace_delta(text)
  local opens = select(2, text:gsub("{", ""))
  local closes = select(2, text:gsub("}", ""))
  return opens - closes
end

local function compact_config_start(label, text, raw)
  state.skip_block = label
  state.block_depth = math.max(1, brace_delta(text))
  return { entry("status", label, raw) }
end

local function parse_dap_payload(direction, payload, raw)
  local msg = json_decode(payload)
  if not msg then
    return { entry("protocol", direction .. " DAP message", raw) }
  end

  if msg.type == "request" then
    local command = msg.command or "request"
    if noisy_requests[command] then
      return {}
    end
    return { entry("protocol", "DAP request: " .. command, raw) }
  end

  if msg.type == "response" then
    local command = msg.command or "response"
    if not msg.success then
      local text = msg.message or ("DAP response failed: " .. command)
      if msg.body and msg.body.error and msg.body.error.format then
        text = msg.body.error.format
      end
      return { entry("error", text, raw) }
    end
    if noisy_responses[command] then
      return {}
    end
    if command == "setBreakpoints" and msg.body and msg.body.breakpoints then
      local verified = 0
      for _, bp in ipairs(msg.body.breakpoints) do
        if bp.verified then
          verified = verified + 1
        end
      end
      return { entry("event", string.format("breakpoints accepted: %d/%d", verified, #msg.body.breakpoints), raw) }
    end
    return { entry("protocol", "DAP response: " .. command, raw) }
  end

  if msg.type == "event" then
    local event_name = msg.event or "event"
    if event_name == "stopped" then
      local body = msg.body or {}
      local reason = body.reason or "stopped"
      return { entry("event", "stopped: " .. reason, raw) }
    end
    if event_name == "process" then
      local body = msg.body or {}
      return {
        entry(
          "event",
          string.format("process started: %s (pid %s)", short_path(body.name), tostring(body.systemProcessId or "?")),
          raw
        ),
      }
    end
    if event_name == "output" then
      local text = (msg.body and msg.body.output) or ""
      text = vim.trim(text)
      if text ~= "" then
        return { entry("program", text, raw) }
      end
      return {}
    end
    return { entry("protocol", "DAP event: " .. event_name, raw) }
  end

  return { entry("raw", "unclassified DAP message", raw) }
end

local function parse_dlv_log(message, raw)
  local from_client = message:match("^%[<%- from client%](.*)$")
  if from_client then
    return parse_dap_payload("client -> dlv", from_client, raw)
  end

  local to_client = message:match("^%[%-%> to client%](.*)$")
  if to_client then
    return parse_dap_payload("dlv -> client", to_client, raw)
  end

  local listen_host, listen_port = message:match("^DAP server listening at:%s*([%d%.]+):(%d+)")
  if listen_host and listen_port then
    return { entry("status", string.format("dlv listening on %s:%s", listen_host, listen_port), raw) }
  end

  local pid = message:match("^DAP server pid = (%d+)")
  if pid then
    return { entry("status", "dlv server pid: " .. pid, raw) }
  end

  if message:match("^DAP connection %d+ started") then
    return { entry("status", "DAP client connected", raw) }
  end

  if message:match("^parsed launch config:%s*{") then
    return compact_config_start("launch config parsed", message, raw)
  end

  local build_dir, build_cmd = message:match('^building from "([^"]+)": %[(.*)%]$')
  if build_dir then
    return {
      entry("status", string.format("building debug binary in %s", short_path(build_dir)), raw),
      entry("detail", build_cmd, raw),
    }
  end

  local exe = message:match("^launching binary '([^']+)' with config:%s*{")
  if exe then
    return compact_config_start("launching debug binary: " .. short_path(exe), message, raw)
  end

  local reason, file, line = message:match('"continue" command stopped %- reason "([^"]+)", location (.+):(%d+)$')
  if reason and file and line then
    return { entry("event", string.format("stopped at %s:%s (%s)", short_path(file), line, reason), raw) }
  end

  if message:match("^Unable to produce stack trace:") then
    return { entry("warn", message, raw) }
  end

  if message:match("error") or message:match("failed") then
    return { entry("error", message, raw) }
  end

  return { entry("raw", message, raw) }
end

local function coalesce(entries)
  local out = {}
  for _, item in ipairs(entries) do
    local signature = item.kind .. "\n" .. item.text
    if signature == state.last_signature and #out > 0 then
      state.repeat_count = state.repeat_count + 1
      out[#out].text = item.text .. " (x" .. tostring(state.repeat_count + 1) .. ")"
    elseif signature == state.last_signature then
      -- repeat from previous call, we can't easily update the UI's historical log here
      -- so we just treat it as a new entry for now to avoid losing data
      state.last_signature = signature
      state.repeat_count = 0
      table.insert(out, item)
    else
      state.last_signature = signature
      state.repeat_count = 0
      table.insert(out, item)
    end
  end
  return out
end

function M.parse_line(line)
  local raw = tostring(line or "")
  local text = vim.trim(raw)
  if text == "" then
    return {}
  end

  if state.skip_block then
    state.block_depth = state.block_depth + brace_delta(text)
    if state.block_depth <= 0 then
      state.skip_block = nil
      state.block_depth = 0
    end
    return {}
  end

  local message = text:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d[%+%-]%d%d:%d%d%s+debug%s+layer=dap%s+(.*)$")
  if message then
    return parse_dlv_log(message, raw)
  end

  if text == "debug UI ready" then
    return { entry("status", "debug UI ready", raw) }
  end

  if text:match("^starting dlv dap in:") then
    local dir = text:match("^starting dlv dap in:%s*(.*)$")
    return { entry("status", "starting Delve in " .. short_path(dir), raw) }
  end

  if text:match("^connecting to dlv at") then
    return { entry("status", text:gsub("^connecting", "connecting"), raw) }
  end

  if text == "connected" then
    return { entry("status", "connected to Delve", raw) }
  end

  if text:match("^process .- %(pid %d+%)$") then
    return { entry("event", text, raw) }
  end

  if text:match("^%d+/%d+ BP verified") or text:match("^%d+/%d+ BP verified in") then
    return { entry("event", text:gsub("BP", "breakpoint"), raw) }
  end

  if text:match("^%[error%]") or text:match("^%[DAP error%]") then
    return { entry("error", text, raw) }
  end

  if text:match("^%[warn%]") then
    return { entry("warn", text, raw) }
  end

  if text:match("^●") or text:match("^▶") or text:match("^⏸") or text:match("^■") then
    return { entry("event", text, raw) }
  end

  return { entry("program", text, raw) }
end

function M.parse(raw)
  local entries = {}
  raw = tostring(raw or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for _, line in ipairs(vim.split(raw, "\n", { plain = true })) do
    vim.list_extend(entries, M.parse_line(line))
  end
  return coalesce(entries)
end

function M.reset()
  state.skip_block = nil
  state.block_depth = 0
  state.last_signature = nil
  state.repeat_count = 0
end

return M
