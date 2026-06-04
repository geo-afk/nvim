-- =============================================================================
--  config/ui.lua  -  Visual & UX layer  (Neovim 0.12+)
-- =============================================================================

local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if not ok_ui2 then
  vim.notify("ui2 unavailable - upgrade to Neovim 0.12+", vim.log.levels.WARN)
  return
end

local ok_msgs, msgs = pcall(require, "vim._core.ui2.messages")
if not ok_msgs then
  vim.notify("ui2 message module unavailable", vim.log.levels.WARN)
  return
end

-- =============================================================================
--  Configuration
-- =============================================================================

local ROUTE_TRIGGER = "__custom_ui_route"

local LEVELS = vim.log.levels
local SEVERITY = {
  error = {
    level = LEVELS.ERROR,
    icon = "",
    label = "Error",
    title = "   Error ",
    title_hl = "CustomNotifyErrorTitle",
    body_hl = "CustomNotifyErrorBody",
    border_hl = "CustomNotifyErrorBorder",
    route = "pager",
    timeout = 8000,
    intrusive = true,
  },
  warn = {
    level = LEVELS.WARN,
    icon = "",
    label = "Warning",
    title = "   Warning ",
    title_hl = "CustomNotifyWarnTitle",
    body_hl = "CustomNotifyWarnBody",
    border_hl = "CustomNotifyWarnBorder",
    route = "msg",
    timeout = 6500,
    intrusive = true,
  },
  info = {
    level = LEVELS.INFO,
    icon = "",
    label = "Info",
    title = "   Info ",
    title_hl = "CustomNotifyInfoTitle",
    body_hl = "CustomNotifyInfoBody",
    border_hl = "CustomNotifyInfoBorder",
    route = "msg",
    timeout = 4200,
    intrusive = false,
  },
  debug = {
    level = LEVELS.DEBUG,
    icon = "",
    label = "Debug",
    title = "   Debug ",
    title_hl = "CustomNotifyDebugTitle",
    body_hl = "CustomNotifyDebugBody",
    border_hl = "CustomNotifyDebugBorder",
    route = "cmd",
    timeout = 2500,
    intrusive = false,
  },
  trace = {
    level = LEVELS.TRACE,
    icon = "",
    label = "Trace",
    title = "   Trace ",
    title_hl = "CustomNotifyDebugTitle",
    body_hl = "CustomNotifyDebugBody",
    border_hl = "CustomNotifyDebugBorder",
    route = "cmd",
    timeout = 2000,
    intrusive = false,
  },
  success = {
    level = LEVELS.INFO,
    icon = "",
    label = "Success",
    title = "   Success ",
    title_hl = "CustomNotifySuccessTitle",
    body_hl = "CustomNotifySuccessBody",
    border_hl = "CustomNotifySuccessBorder",
    route = "msg",
    timeout = 3500,
    intrusive = false,
  },
}

local KIND_SEVERITY = {
  emsg = "error",
  echoerr = "error",
  lua_error = "error",
  rpc_error = "error",
  shell_err = "error",
  wmsg = "warn",
  progress = "info",
  verbose = "debug",
}

local POLICY = {
  defer_ms = 450,
  duplicate_window_ms = 3500,
  max_msg_width_ratio = 0.46,
  max_msg_height = 6,
  max_deferred_preview = 3,
  msg_winblend = 0,
}

local IGNORED_KINDS = {
  [""] = true,
  empty = true,
  bufwrite = true,
}

local SPECIAL_KINDS = {
  search_count = true,
  search_cmd = true,
  confirm = true,
  wildlist = true,
  typed_cmd = true,
}

local SKIP_PATTERNS = {
  "%d+L, %d+B",
  "; after #%d+",
  "; before #%d+",
  "^[/?].*",
  "E486: Pattern not found:",
  "%d+ less lines",
  "%d+ fewer lines",
  "%d+ more lines",
  "%d+ change;",
  "%d+ line less;",
  "%d+ more lines?;",
  "%d+ fewer lines;?",
  "1 more line",
  "1 line less",
  "^Hunk %d+ of %d+$",
  "Already at newest change",
  "Already at oldest change",
  "%d lines yanked",
  "no lines in buffer",
  "%d+ changes?;",
  " changes; before #",
  " changes; after #",
  " 1 change; before #",
  " 1 change; after #",
  " lines moved",
  " lines indented",
}

-- =============================================================================
--  Runtime State
-- =============================================================================

local originals = msgs._custom_ui_originals or {
  set_pos = msgs.set_pos,
  msg_show = msgs.msg_show,
  show_msg = msgs.show_msg,
  notify = vim.notify,
}
msgs._custom_ui_originals = originals

local state = {
  title = SEVERITY.info.title,
  title_hl = SEVERITY.info.title_hl,
  body_hl = SEVERITY.info.body_hl,
  border_hl = SEVERITY.info.border_hl,
  duplicate = {},
  deferred = {},
  defer_timer = nil,
  flushing = false,
}

-- =============================================================================
--  Highlights
-- =============================================================================

local function define_highlights()
  local set = vim.api.nvim_set_hl

  set(0, "CustomNotifyErrorTitle", { fg = "#f7768e", bg = "NONE", bold = true })
  set(0, "CustomNotifyErrorBorder", { fg = "#f7768e", bg = "NONE" })
  set(0, "CustomNotifyErrorBody", { bg = "NONE" })

  set(0, "CustomNotifyWarnTitle", { fg = "#e0af68", bg = "NONE", bold = true })
  set(0, "CustomNotifyWarnBorder", { fg = "#e0af68", bg = "NONE" })
  set(0, "CustomNotifyWarnBody", { bg = "NONE" })

  set(0, "CustomNotifyInfoTitle", { fg = "#7aa2f7", bg = "NONE", bold = true })
  set(0, "CustomNotifyInfoBorder", { fg = "#7aa2f7", bg = "NONE" })
  set(0, "CustomNotifyInfoBody", { bg = "NONE" })

  set(0, "CustomNotifySuccessTitle", { fg = "#9ece6a", bg = "NONE", bold = true })
  set(0, "CustomNotifySuccessBorder", { fg = "#9ece6a", bg = "NONE" })
  set(0, "CustomNotifySuccessBody", { bg = "NONE" })

  set(0, "CustomNotifyDebugTitle", { fg = "#7f849c", bg = "NONE" })
  set(0, "CustomNotifyDebugBorder", { fg = "#565f89", bg = "NONE" })
  set(0, "CustomNotifyDebugBody", { fg = "#7f849c", bg = "NONE" })

  set(0, "CustomNotifyDim", { fg = "#565f89", bg = "NONE" })
  set(0, "CustomNotifyFloat", { bg = "#1a1b26" })
end

define_highlights()

-- =============================================================================
--  Helpers
-- =============================================================================

local function now_ms()
  return math.floor(vim.uv.hrtime() / 1000000)
end

local function content_to_text(content)
  if type(content) ~= "table" then
    return tostring(content or "")
  end

  local parts = {}
  for _, chunk in ipairs(content) do
    if type(chunk) == "table" then
      parts[#parts + 1] = tostring(chunk[2] or chunk[1] or "")
    else
      parts[#parts + 1] = tostring(chunk)
    end
  end
  return table.concat(parts)
end

local function normalize_text(text)
  text = vim.trim(tostring(text or ""))
  text = text:gsub("%s+", " ")
  return text
end

local function message_size(content)
  local text = content_to_text(content)
  local lines = vim.split(text, "\n", { plain = true })
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(line))
  end
  return width, #lines, text
end

local function should_skip(kind, content)
  if IGNORED_KINDS[kind or ""] then
    return true
  end

  local text = content_to_text(content)
  for _, pat in ipairs(SKIP_PATTERNS) do
    if text:find(pat) then
      return true
    end
  end
  return false
end

local function severity_from_level(level, opts)
  opts = opts or {}
  local category = type(opts.category) == "string" and opts.category:lower() or nil
  if category and SEVERITY[category] then
    return category
  end

  if type(level) == "string" then
    local name = level:lower()
    if name == "warning" then
      name = "warn"
    end
    if SEVERITY[name] then
      return name
    end
    level = LEVELS[level:upper()]
  end

  level = tonumber(level or LEVELS.INFO) or LEVELS.INFO
  if level >= LEVELS.ERROR then
    return "error"
  elseif level >= LEVELS.WARN then
    return "warn"
  elseif level <= LEVELS.TRACE then
    return "trace"
  elseif level <= LEVELS.DEBUG then
    return "debug"
  end
  return "info"
end

local function classify(kind, content, opts)
  opts = opts or {}
  local severity_name = opts.severity or KIND_SEVERITY[kind] or "info"
  if type(severity_name) == "string" then
    severity_name = severity_name:lower()
  end
  if not SEVERITY[severity_name] then
    severity_name = "info"
  end

  local severity = vim.tbl_extend("force", SEVERITY[severity_name], opts.style or {})
  local text = normalize_text(content_to_text(content))
  local width, height = message_size(content)
  local route = opts.route or severity.route

  if route == "msg" and (width > math.floor(vim.o.columns * POLICY.max_msg_width_ratio) or height > POLICY.max_msg_height) then
    route = "pager"
  end

  return {
    name = severity_name,
    severity = severity,
    text = text,
    width = width,
    height = height,
    route = route,
    key = (opts.id or kind or "msg") .. "\n" .. text,
    intrusive = severity.intrusive == true,
  }
end

local function is_typing()
  local mode = vim.api.nvim_get_mode().mode
  return mode:match("^[iR]") ~= nil or mode == "c" or vim.fn.getcmdwintype() ~= ""
end

local function with_route(route, fn)
  local targets = ui2.cfg and ui2.cfg.msg and ui2.cfg.msg.targets
  if not targets or not route then
    return fn()
  end

  local old = targets[ROUTE_TRIGGER]
  targets[ROUTE_TRIGGER] = route
  local ok, result = pcall(fn)
  targets[ROUTE_TRIGGER] = old
  if not ok then
    error(result)
  end
  return result
end

local function echo_text(text, severity_name, opts)
  opts = opts or {}
  local sev = SEVERITY[severity_name] or SEVERITY.info
  local chunks = { { text, opts.hl or sev.body_hl } }
  local echo_opts = {
    id = opts.id,
    kind = opts.kind or (severity_name == "error" and "emsg" or severity_name == "warn" and "wmsg" or "echo"),
  }
  state.flushing = true
  local ok, ret = pcall(vim.api.nvim_echo, chunks, opts.history ~= false, echo_opts)
  state.flushing = false
  return ok and ret or nil
end

local function compact_message(text, severity_name, opts)
  opts = opts or {}
  local sev = SEVERITY[severity_name] or SEVERITY.info
  local icon = opts.icon or sev.icon
  local title = opts.title
  text = type(text) == "table" and table.concat(text, "\n") or tostring(text or "")
  text = vim.trim(text)
  if title and title ~= "" then
    return ("%s %s: %s"):format(icon, title, text)
  end
  return ("%s %s"):format(icon, text)
end

local function schedule_deferred_flush()
  if state.defer_timer then
    state.defer_timer:stop()
  else
    state.defer_timer = vim.uv.new_timer()
  end

  state.defer_timer:start(
    POLICY.defer_ms,
    0,
    vim.schedule_wrap(function()
      if is_typing() or #state.deferred == 0 then
        schedule_deferred_flush()
        return
      end

      local pending = state.deferred
      state.deferred = {}
      if #pending == 1 then
        local item = pending[1]
        echo_text(item.message, item.severity_name, {
          id = item.id,
          kind = "echo",
          hl = item.hl,
        })
        return
      end

      local lines = {}
      local start = math.max(1, #pending - POLICY.max_deferred_preview + 1)
      for i = start, #pending do
        lines[#lines + 1] = pending[i].message:gsub("\n.*", "")
      end

      local hidden = #pending - #lines
      local prefix = hidden > 0 and (hidden .. " older, ") or ""
      echo_text((" %s%d background messages while typing\n%s"):format(prefix, #lines, table.concat(lines, "\n")), "info", {
        id = "custom-ui-deferred-summary",
        kind = "echo",
        hl = "CustomNotifyDim",
      })
    end)
  )
end

local function defer_notification(item, text, severity_name, opts)
  state.deferred[#state.deferred + 1] = {
    id = opts and opts.id,
    message = text,
    severity_name = severity_name,
    hl = (SEVERITY[severity_name] or SEVERITY.info).body_hl,
  }
  schedule_deferred_flush()
end

local function apply_duplicate_policy(item, content, id, replace_last)
  if item.text == "" then
    return content, id, replace_last
  end

  local stamp = now_ms()
  local prev = state.duplicate[item.key]
  if not prev or stamp - prev.stamp > POLICY.duplicate_window_ms then
    state.duplicate[item.key] = { stamp = stamp, count = 1 }
    return content, id or item.key, replace_last
  end

  prev.stamp = stamp
  prev.count = prev.count + 1
  local text = ("%s  (x%d)"):format(item.text, prev.count)
  local sev = item.severity
  return { { 0, text, 0 } }, id or item.key, true
end

local function cursor_screenpos()
  local ok, pos = pcall(vim.fn.screenpos, 0, vim.fn.line("."), vim.fn.col("."))
  if ok and type(pos) == "table" and tonumber(pos.row) and tonumber(pos.col) then
    return tonumber(pos.row), tonumber(pos.col)
  end
  return 0, 0
end

local function style_win(win, target)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  if not ok or cfg.hide then
    return
  end

  local winhl = table.concat({
    "Normal:CustomNotifyFloat",
    "NormalNC:CustomNotifyFloat",
    "NormalFloat:CustomNotifyFloat",
    "EndOfBuffer:CustomNotifyFloat",
    "FloatBorder:" .. (state.border_hl or "FloatBorder"),
    "FloatTitle:" .. (state.title_hl or "FloatTitle"),
  }, ",")
  pcall(vim.api.nvim_set_option_value, "winhighlight", winhl, { scope = "local", win = win })
  pcall(vim.api.nvim_set_option_value, "winblend", POLICY.msg_winblend, { scope = "local", win = win })

  local next_cfg = {
    border = target == "msg" and "rounded" or cfg.border,
    style = "minimal",
    title = { { state.title or " Notification ", state.title_hl or "FloatTitle" } },
    title_pos = "left",
  }

  if target == "msg" then
    local cursor_row, cursor_col = cursor_screenpos()
    local width = cfg.width or math.floor(vim.o.columns * 0.35)
    local near_top_right = cursor_row > 0
      and cursor_row <= math.max(6, (cfg.height or 1) + 3)
      and cursor_col >= math.max(1, vim.o.columns - width - 6)

    next_cfg.relative = "editor"
    next_cfg.anchor = near_top_right and "SE" or "NE"
    next_cfg.row = near_top_right and math.max(1, vim.o.lines - 2) or 1
    next_cfg.col = vim.o.columns - 2
    next_cfg.width = math.max(24, math.min(width, math.floor(vim.o.columns * 0.46)))
    next_cfg.focusable = false
  end

  pcall(vim.api.nvim_win_set_config, win, next_cfg)
end

-- =============================================================================
--  ui2 Enable
-- =============================================================================

ui2.enable({
  enable = true,
  msg = {
    targets = {
      default = "cmd",
      [""] = "cmd",
      empty = "cmd",
      bufwrite = "cmd",
      confirm = "cmd",
      emsg = "pager",
      echo = "msg",
      echomsg = "msg",
      echoerr = "pager",
      completion = "cmd",
      list_cmd = "pager",
      lua_error = "pager",
      lua_print = "msg",
      progress = "msg",
      rpc_error = "pager",
      quickfix = "cmd",
      search_cmd = "cmd",
      search_count = "cmd",
      shell_cmd = "pager",
      shell_err = "pager",
      shell_out = "pager",
      shell_ret = "cmd",
      undo = "cmd",
      verbose = "cmd",
      wildlist = "cmd",
      wmsg = "msg",
      typed_cmd = "cmd",
    },
    cmd = { height = 0.12 },
    dialog = { height = 0.38 },
    msg = { height = 0.22, timeout = 4200 },
    pager = { height = 0.42 },
  },
})

-- =============================================================================
--  Message Routing
-- =============================================================================

msgs.set_pos = function(tgt)
  originals.set_pos(tgt)
  if not ui2.wins then
    return
  end

  if tgt then
    style_win(ui2.wins[tgt], tgt)
    return
  end

  for name, win in pairs(ui2.wins) do
    style_win(win, name)
  end
end

msgs.show_msg = function(tgt, kind, content, replace_last, append, id)
  if tgt == "msg" then
    local width, height = message_size(content)
    if width > math.floor(vim.o.columns * POLICY.max_msg_width_ratio) or height > POLICY.max_msg_height then
      return originals.show_msg("pager", kind, content, replace_last, append, id)
    end
  end
  return originals.show_msg(tgt, kind, content, replace_last, append, id)
end

msgs.msg_show = function(kind, content, replace_last, history, append, id, trigger)
  if state.flushing or vim.g.custom_cmdline_busy or SPECIAL_KINDS[kind] then
    return originals.msg_show(kind, content, replace_last, history, append, id, trigger)
  end

  if should_skip(kind, content) then
    return
  end

  local item = classify(kind, content)
  state.title = item.severity.title
  state.title_hl = item.severity.title_hl
  state.body_hl = item.severity.body_hl
  state.border_hl = item.severity.border_hl

  if is_typing() and not item.intrusive and item.route == "msg" then
    defer_notification(item, content_to_text(content), item.name, { id = id })
    return
  end

  content, id, replace_last = apply_duplicate_policy(item, content, id, replace_last)
  return with_route(item.route, function()
    return originals.msg_show(kind, content, replace_last, history, append, id, ROUTE_TRIGGER)
  end)
end

vim.notify = function(msg, level, opts)
  if vim.g.custom_cmdline_busy then
    return originals.notify(msg, level, opts)
  end

  opts = opts or {}
  local severity_name = severity_from_level(level, opts)
  local severity = SEVERITY[severity_name] or SEVERITY.info
  local text = compact_message(msg, severity_name, {
    icon = opts.icon,
    title = opts.title,
  })

  local function emit()
    local kind = opts.kind or (severity_name == "error" and "emsg" or severity_name == "warn" and "wmsg" or "echo")
    local item = {
      key = tostring(opts.id or kind) .. "\n" .. normalize_text(text),
      text = normalize_text(text),
      route = opts.route or severity.route,
      intrusive = severity.intrusive,
      severity = severity,
      name = severity_name,
    }

    if is_typing() and not item.intrusive and item.route == "msg" then
      defer_notification(item, text, severity_name, opts)
      return opts.id
    end

    state.title = severity.title
    state.title_hl = severity.title_hl
    state.body_hl = severity.body_hl
    state.border_hl = severity.border_hl
    return echo_text(text, severity_name, {
      id = opts.id,
      kind = kind,
      hl = severity.body_hl,
    })
  end

  if vim.in_fast_event() then
    vim.schedule(emit)
    return opts.id
  end
  return emit()
end

vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave", "CursorHold" }, {
  group = vim.api.nvim_create_augroup("CustomUISmartNotify", { clear = true }),
  callback = function()
    if #state.deferred > 0 then
      schedule_deferred_flush()
    end
  end,
})

-- =============================================================================
--  LSP Progress
-- =============================================================================

vim.api.nvim_create_autocmd("LspProgress", {
  group = vim.api.nvim_create_augroup("LspProgressUI2", { clear = true }),
  callback = function(ev)
    local value = ev.data.params.value
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or not value then
      return
    end

    local is_end = value.kind == "end"
    local pct = value.percentage and ("%3d%%"):format(value.percentage) or "---%"
    local label = (value.message ~= "" and value.message or value.title or ""):sub(1, 24)

    vim.api.nvim_echo({ { ("  %-10s  %-24s  %s"):format(client.name:sub(1, 10), label, pct), "CustomNotifyInfoBody" } }, false, {
      id = "lsp.progress",
      kind = "progress",
      source = "vim.lsp",
      status = is_end and "success" or "running",
    })
  end,
})

-- =============================================================================
--  Deferred Setup
-- =============================================================================

vim.schedule(function()
  pcall(function()
    require("config.ui_showcase").setup()
  end)
  vim.api.nvim_set_hl(0, "@module.last", { link = "Type", bold = true, italic = true })
end)
