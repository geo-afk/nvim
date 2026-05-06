local api = vim.api
local fn = vim.fn

local nvim_utils = require("utils.nvim")

local M = {}

local TITLE = " Vim.pack Manager "
local NS = api.nvim_create_namespace("custom_pack_manager")

local state = {
  index = {},
  plugins = {},
  filtered = {},
  selection = 1,
  query = "",
  active_only = false,
  tab = "details",
  metrics = {},
  close_on_action = false,
  wins = {},
  bufs = {},
  augroup = nil,
}

local function set_buf_opt(buf, name, value)
  api.nvim_set_option_value(name, value, { buf = buf })
end

local function set_win_opt(win, name, value)
  api.nvim_set_option_value(name, value, { win = win })
end

local function escape_lua_pattern(text)
  return (text:gsub("([^%w])", "%%%1"))
end

local function trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function derive_name(src)
  if not src or src == "" then
    return "unknown"
  end
  local clean = src:gsub("/+$", ""):gsub("%.git$", "")
  return clean:match("([^/]+)$") or clean
end

local function repo_slug(src)
  if not src or src == "" then
    return nil
  end
  return src:match("github%.com[:/]([^/]+/[^/]+)%.git$")
    or src:match("github%.com[:/]([^/]+/[^/]+)$")
    or src:match("codeberg%.org[:/]([^/]+/[^/]+)%.git$")
    or src:match("codeberg%.org[:/]([^/]+/[^/]+)$")
end

local function version_text(version)
  if version == nil then
    return "default"
  end
  local ok, rendered = pcall(tostring, version)
  if not ok or rendered == nil or rendered == "" then
    return "<complex>"
  end
  return rendered
end

local function setup_highlights()
  local define = function(name, spec)
    vim.api.nvim_set_hl(0, name, spec)
  end

  define("PackManagerNormal", { link = "NormalFloat", default = true })
  define("PackManagerBorder", { link = "FloatBorder", default = true })
  define("PackManagerTitle", { link = "FloatTitle", default = true })
  define("PackManagerMuted", { link = "Comment", default = true })
  define("PackManagerAccent", { link = "Identifier", default = true })
  define("PackManagerValue", { link = "String", default = true })
  define("PackManagerOk", { link = "DiagnosticOk", default = true })
  define("PackManagerWarn", { link = "DiagnosticWarn", default = true })
  define("PackManagerDanger", { link = "DiagnosticError", default = true })
  define("PackManagerCursor", { link = "Visual", default = true })
  define("PackManagerSection", { link = "Title", default = true })
  define("PackManagerPath", { link = "Directory", default = true })
  define("PackManagerCode", { link = "Normal", default = true })
  define("PackManagerHint", { link = "SpecialComment", default = true })
end

local function read_json(path)
  if fn.filereadable(path) == 0 then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function detect_line(lines, pattern)
  for i, line in ipairs(lines) do
    if line:find(pattern) then
      return i
    end
  end
  return 1
end

local function snippet_from_lines(lines, anchor)
  local first = math.max(1, anchor - 2)
  local last = math.min(#lines, first + 35)
  local out = {}
  for i = first, last do
    out[#out + 1] = string.format("%4d | %s", i, lines[i])
  end
  if last < #lines then
    out[#out + 1] = string.format(" ... (%d more lines)", #lines - last)
  end
  return out
end

local function parse_plugin_file(path)
  local lines = fn.readfile(path)
  local text = table.concat(lines, "\n")
  local entries = {}

  for quote, src, rest in text:gmatch("{%s*src%s*=%s*([\"'])(.-)%1(.-)}") do
    local _ = quote
    local name = rest:match("name%s*=%s*['\"](.-)['\"]") or derive_name(src)
    local build = trim(rest:match("build%s*=%s*([^,\n]+)") or "")
    local version = trim(rest:match("version%s*=%s*([^,\n]+)") or "")
    local anchor = detect_line(lines, escape_lua_pattern(src))

    entries[#entries + 1] = {
      name = name,
      src = src,
      source_file = path,
      source_line = anchor,
      version = version ~= "" and version or nil,
      build = build ~= "" and build or nil,
      snippet = snippet_from_lines(lines, anchor),
    }
  end

  return entries
end

local function build_config_index()
  local root = vim.fs.joinpath(fn.stdpath("config"), "lua", "plugins")
  local files = vim.fn.globpath(root, "*.lua", false, true)
  local index = {}

  for _, path in ipairs(files) do
    for _, entry in ipairs(parse_plugin_file(path)) do
      index[entry.name] = index[entry.name] or {}
      table.insert(index[entry.name], entry)
    end
  end

  return index
end

local function safe_pack_get()
  local ok, plugins = pcall(vim.pack.get, nil, { info = true })
  if not ok then
    vim.notify("vim.pack.get() failed: " .. tostring(plugins), vim.log.levels.ERROR)
    return {}
  end
  return plugins
end

local function count(list)
  return type(list) == "table" and #list or 0
end

local function bool_text(value)
  return value and "yes" or "no"
end

local function enrich_plugins()
  local lockfile = read_json(vim.fs.joinpath(fn.stdpath("config"), "nvim-pack-lock.json"))
  local lock_plugins = type(lockfile.plugins) == "table" and lockfile.plugins or {}
  state.index = build_config_index()

  local plugins = safe_pack_get()
  table.sort(plugins, function(a, b)
    if a.active ~= b.active then
      return a.active and not b.active
    end
    return a.spec.name < b.spec.name
  end)

  state.plugins = vim.tbl_map(function(plugin)
    local configs = state.index[plugin.spec.name] or {}
    local locked = lock_plugins[plugin.spec.name] or {}
    local on_disk = vim.uv.fs_stat(plugin.path) ~= nil
    plugin._pm = {
      display_name = plugin.spec.name,
      src = plugin.spec.src,
      version = version_text(plugin.spec.version),
      repo = repo_slug(plugin.spec.src),
      config = configs,
      config_count = #configs,
      lock_rev = locked.rev,
      branches_count = count(plugin.branches),
      tags_count = count(plugin.tags),
      on_disk = on_disk,
      build = configs[1] and configs[1].build or nil,
      lock_mismatch = locked.rev ~= nil and plugin.rev ~= nil and locked.rev ~= plugin.rev,
    }
    return plugin
  end, plugins)

  local metrics = {
    total = #state.plugins,
    active = 0,
    inactive = 0,
    configless = 0,
    lock_mismatch = 0,
    missing_path = 0,
  }
  for _, plugin in ipairs(state.plugins) do
    if plugin.active then
      metrics.active = metrics.active + 1
    else
      metrics.inactive = metrics.inactive + 1
    end
    if plugin._pm.config_count == 0 then
      metrics.configless = metrics.configless + 1
    end
    if plugin._pm.lock_mismatch then
      metrics.lock_mismatch = metrics.lock_mismatch + 1
    end
    if not plugin._pm.on_disk then
      metrics.missing_path = metrics.missing_path + 1
    end
  end
  state.metrics = metrics
end

local function plugin_matches(plugin, query)
  if query == "" then
    return true
  end
  local haystacks = {
    plugin.spec.name,
    plugin.spec.src,
    plugin._pm.repo,
    plugin.path,
  }
  query = query:lower()
  for _, candidate in ipairs(haystacks) do
    if type(candidate) == "string" and candidate:lower():find(query, 1, true) then
      return true
    end
  end
  return false
end

local function apply_filter()
  state.filtered = {}
  for _, plugin in ipairs(state.plugins) do
    if (not state.active_only or plugin.active) and plugin_matches(plugin, state.query) then
      table.insert(state.filtered, plugin)
    end
  end
  if #state.filtered == 0 then
    state.selection = 1
  else
    state.selection = math.max(1, math.min(state.selection, #state.filtered))
  end
end

local function current_plugin()
  return state.filtered[state.selection]
end

local function close()
  for _, win in pairs(state.wins) do
    if win and api.nvim_win_is_valid(win) then
      pcall(api.nvim_win_close, win, true)
    end
  end
  for _, buf in pairs(state.bufs) do
    if buf and api.nvim_buf_is_valid(buf) then
      pcall(api.nvim_buf_delete, buf, { force = true })
    end
  end
  state.wins = {}
  state.bufs = {}
end

local function update_statusline()
  local win = state.wins.frame
  if not win or not api.nvim_win_is_valid(win) then
    return
  end
  local mode = state.active_only and "active" or "all"
  local plugin = current_plugin()
  local selected = plugin and plugin.spec.name or "none"
  local action_mode = state.close_on_action and "close" or "stay"
  local line = table.concat({
    " ",
    string.format("%d/%d shown", #state.filtered, #state.plugins),
    string.format("mode:%s", mode),
    "tab:" .. state.tab,
    "actions:" .. action_mode,
    state.query ~= "" and ("query:" .. state.query) or "query:<none>",
    "selected:" .. selected,
    "%=",
    " 1 details  2 update  3 check  p toggle-close  u update  U all  O offline  L lockfile  e config  o repo  / filter  q close ",
  }, "  ")
  set_win_opt(win, "statusline", line)
end

local function render_list()
  local buf = state.bufs.list
  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {
    " Plugins",
    "",
  }
  local meta = {}

  if #state.filtered == 0 then
    lines[#lines + 1] = "  No plugins match the current filter."
    meta[#meta + 1] = { row = #lines - 1, kind = "muted" }
  else
    for i, plugin in ipairs(state.filtered) do
      local icon = plugin.active and "●" or "○"
      local mark = i == state.selection and "▌" or " "
      local text = string.format("%s %s %-28s %s", mark, icon, plugin.spec.name, plugin._pm.version)
      lines[#lines + 1] = text
      meta[#meta + 1] = {
        row = #lines - 1,
        selected = i == state.selection,
        active = plugin.active,
      }
    end
  end

  set_buf_opt(buf, "modifiable", true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_opt(buf, "modifiable", false)
  api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  require("custom.ui.render").add_highlight(buf, NS, "PackManagerSection", 0, 0, -1)
  for _, item in ipairs(meta) do
    local group = item.active and "PackManagerOk" or "PackManagerMuted"
    require("custom.ui.render").add_highlight(buf, NS, group, item.row, 2, 3)
    require("custom.ui.render").add_highlight(buf, NS, "PackManagerAccent", item.row, 4, 32)
    require("custom.ui.render").add_highlight(buf, NS, "PackManagerValue", item.row, 33, -1)
    if item.selected then
      require("custom.ui.render").add_highlight(buf, NS, "PackManagerCursor", item.row, 0, -1)
    end
  end

  local cursor_row = math.max(3, state.selection + 2)
  if state.wins.list and api.nvim_win_is_valid(state.wins.list) then
    pcall(api.nvim_win_set_cursor, state.wins.list, { cursor_row, 0 })
  end
end

local function append_kv(lines, hls, label, value, group)
  local row = #lines
  lines[#lines + 1] = string.format(" %-11s %s", label, value)
  hls[#hls + 1] = { row = row, start_col = 1, end_col = 12, group = "PackManagerMuted" }
  hls[#hls + 1] = { row = row, start_col = 12, end_col = -1, group = group or "PackManagerValue" }
end

local function add_line(lines, hls, text, group)
  local row = #lines
  lines[#lines + 1] = text
  hls[#hls + 1] = { row = row, start_col = 0, end_col = -1, group = group or "PackManagerValue" }
end

local function render_tabs(lines, hls)
  local labels = {
    { key = "details", label = "[1] Details" },
    { key = "update", label = "[2] Update" },
    { key = "check", label = "[3] Check" },
  }

  local parts = {}
  for _, item in ipairs(labels) do
    parts[#parts + 1] = item.label
  end
  local row = #lines
  lines[#lines + 1] = " " .. table.concat(parts, "   ")

  local col = 1
  for _, item in ipairs(labels) do
    local text = item.label
    hls[#hls + 1] = {
      row = row,
      start_col = col,
      end_col = col + #text,
      group = item.key == state.tab and "PackManagerAccent" or "PackManagerMuted",
    }
    col = col + #text + 3
  end

  lines[#lines + 1] = ""
end

local function render_details_tab(plugin, lines, hls)
  local mode_group = plugin.active and "PackManagerOk" or "PackManagerWarn"
  add_line(lines, hls, " Details", "PackManagerSection")
  lines[#lines + 1] = ""
  append_kv(lines, hls, "Name", plugin.spec.name, "PackManagerAccent")
  append_kv(lines, hls, "State", plugin.active and "active in current session" or "installed but not added", mode_group)
  append_kv(lines, hls, "Version", plugin._pm.version)
  append_kv(lines, hls, "Revision", plugin.rev or "unknown")
  append_kv(lines, hls, "Locked", plugin._pm.lock_rev or "not pinned")
  append_kv(lines, hls, "Source", plugin.spec.src, "PackManagerPath")
  append_kv(lines, hls, "Repo", plugin._pm.repo or "n/a", "PackManagerPath")
  append_kv(lines, hls, "Path", plugin.path, "PackManagerPath")
  append_kv(lines, hls, "On Disk", bool_text(plugin._pm.on_disk), plugin._pm.on_disk and "PackManagerOk" or "PackManagerDanger")
  append_kv(lines, hls, "Branches", tostring(plugin._pm.branches_count))
  append_kv(lines, hls, "Tags", tostring(plugin._pm.tags_count))
  append_kv(lines, hls, "Build", plugin._pm.build or "none")

  lines[#lines + 1] = ""
  add_line(lines, hls, " Config Links", "PackManagerSection")
  if #plugin._pm.config == 0 then
    add_line(lines, hls, " No matching vim.pack.add() declaration was found in lua/plugins.", "PackManagerMuted")
  else
    for _, config in ipairs(plugin._pm.config) do
      add_line(lines, hls, string.format(" %s:%d", fn.fnamemodify(config.source_file, ":~"), config.source_line), "PackManagerPath")
    end
  end

  lines[#lines + 1] = ""
  add_line(lines, hls, " Config Snippet", "PackManagerSection")
  local snippet = (#plugin._pm.config > 0 and plugin._pm.config[1].snippet) or { " No snippet available." }
  for _, text in ipairs(snippet) do
    add_line(lines, hls, text, "PackManagerCode")
  end
end

local function render_update_tab(plugin, lines, hls)
  local status_group = plugin._pm.lock_mismatch and "PackManagerWarn" or "PackManagerOk"
  add_line(lines, hls, " Update", "PackManagerSection")
  lines[#lines + 1] = ""
  append_kv(lines, hls, "Plugin", plugin.spec.name, "PackManagerAccent")
  append_kv(lines, hls, "Current", plugin.rev or "unknown")
  append_kv(lines, hls, "Lockfile", plugin._pm.lock_rev or "not pinned", status_group)
  append_kv(lines, hls, "Mismatch", bool_text(plugin._pm.lock_mismatch), status_group)
  append_kv(lines, hls, "Tracked", plugin._pm.version)
  append_kv(lines, hls, "Build Hook", plugin._pm.build or "none")

  lines[#lines + 1] = ""
  add_line(lines, hls, " Actions", "PackManagerSection")
  add_line(lines, hls, " u  update selected plugin now", "PackManagerHint")
  add_line(lines, hls, " O  open offline review for selected plugin", "PackManagerHint")
  add_line(lines, hls, " L  sync selected plugin to lockfile target", "PackManagerHint")
  add_line(lines, hls, " U  update every managed plugin", "PackManagerHint")
  add_line(lines, hls, " x  delete selected inactive plugin", "PackManagerHint")

  lines[#lines + 1] = ""
  add_line(lines, hls, " Workflow Notes", "PackManagerSection")
  add_line(lines, hls, " Review tabs and lockfiles are inspired by lazy.nvim and mini.deps snapshot-style flows.", "PackManagerMuted")
  add_line(lines, hls, " vim.pack's native review buffer remains the source of truth for confirming changes.", "PackManagerMuted")
  add_line(lines, hls, " For plugin source/version switches, update lua/plugins first, then use offline or lockfile sync.", "PackManagerMuted")
end

local function render_check_tab(plugin, lines, hls)
  local git_ok = fn.executable("git") == 1
  local lock_ok = fn.filereadable(vim.fs.joinpath(fn.stdpath("config"), "nvim-pack-lock.json")) == 1

  add_line(lines, hls, " Check", "PackManagerSection")
  lines[#lines + 1] = ""
  append_kv(lines, hls, "Git", bool_text(git_ok), git_ok and "PackManagerOk" or "PackManagerDanger")
  append_kv(lines, hls, "Lockfile", bool_text(lock_ok), lock_ok and "PackManagerOk" or "PackManagerDanger")
  append_kv(lines, hls, "Path Exists", bool_text(plugin._pm.on_disk), plugin._pm.on_disk and "PackManagerOk" or "PackManagerDanger")
  append_kv(lines, hls, "Has Config", bool_text(plugin._pm.config_count > 0), plugin._pm.config_count > 0 and "PackManagerOk" or "PackManagerWarn")
  append_kv(lines, hls, "Lock Drift", bool_text(plugin._pm.lock_mismatch), plugin._pm.lock_mismatch and "PackManagerWarn" or "PackManagerOk")
  append_kv(lines, hls, "Active", bool_text(plugin.active), plugin.active and "PackManagerOk" or "PackManagerMuted")

  lines[#lines + 1] = ""
  add_line(lines, hls, " Workspace Summary", "PackManagerSection")
  add_line(lines, hls, string.format(" total plugins      %d", state.metrics.total or 0), "PackManagerValue")
  add_line(lines, hls, string.format(" active plugins     %d", state.metrics.active or 0), "PackManagerValue")
  add_line(lines, hls, string.format(" inactive plugins   %d", state.metrics.inactive or 0), "PackManagerValue")
  add_line(lines, hls, string.format(" configless plugins %d", state.metrics.configless or 0), "PackManagerValue")
  add_line(lines, hls, string.format(" lock drift count   %d", state.metrics.lock_mismatch or 0), "PackManagerValue")
  add_line(lines, hls, string.format(" missing paths      %d", state.metrics.missing_path or 0), "PackManagerValue")

  lines[#lines + 1] = ""
  add_line(lines, hls, " Manager Ideas Carried Over", "PackManagerSection")
  add_line(lines, hls, " lazy.nvim-style details and quick navigation", "PackManagerMuted")
  add_line(lines, hls, " mini.deps-style snapshot/lock awareness and cleanup mindset", "PackManagerMuted")
  add_line(lines, hls, " packer-style update/build hook visibility", "PackManagerMuted")
end

local function render_detail()
  local buf = state.bufs.detail
  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local plugin = current_plugin()
  local lines = {}
  local hls = {}

  if not plugin then
    lines = {
      " Plugin Details",
      "",
      " No plugin selected.",
    }
    hls = {
      { row = 0, start_col = 0, end_col = -1, group = "PackManagerSection" },
      { row = 2, start_col = 0, end_col = -1, group = "PackManagerMuted" },
    }
  else
    render_tabs(lines, hls)
    if state.tab == "details" then
      render_details_tab(plugin, lines, hls)
    elseif state.tab == "update" then
      render_update_tab(plugin, lines, hls)
    else
      render_check_tab(plugin, lines, hls)
    end
  end

  set_buf_opt(buf, "modifiable", true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_opt(buf, "modifiable", false)
  api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  for _, hl in ipairs(hls) do
    require("custom.ui.render").add_highlight(buf, NS, hl.group, hl.row, hl.start_col, hl.end_col)
  end
end

local function refresh()
  enrich_plugins()
  apply_filter()
  render_list()
  render_detail()
  update_statusline()
end

local function resize()
  if not (state.wins.frame and api.nvim_win_is_valid(state.wins.frame)) then
    return
  end

  local width = math.max(90, math.floor(vim.o.columns * 0.88))
  local height = math.max(26, math.floor(vim.o.lines * 0.82))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))
  local list_width = math.max(34, math.floor(width * 0.34))
  local detail_width = width - list_width - 3

  api.nvim_win_set_config(state.wins.frame, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
  })

  api.nvim_win_set_config(state.wins.list, {
    relative = "win",
    win = state.wins.frame,
    row = 1,
    col = 1,
    width = list_width,
    height = height - 3,
  })

  api.nvim_win_set_config(state.wins.detail, {
    relative = "win",
    win = state.wins.frame,
    row = 1,
    col = list_width + 2,
    width = detail_width,
    height = height - 3,
  })
end

local function focus_list()
  if state.wins.list and api.nvim_win_is_valid(state.wins.list) then
    api.nvim_set_current_win(state.wins.list)
  end
end

local function focus_detail()
  if state.wins.detail and api.nvim_win_is_valid(state.wins.detail) then
    api.nvim_set_current_win(state.wins.detail)
  end
end

local function open_config()
  local plugin = current_plugin()
  if not plugin or #plugin._pm.config == 0 then
    vim.notify("No config file found for this plugin.", vim.log.levels.WARN)
    return
  end
  local target = plugin._pm.config[1]
  close()
  vim.schedule(function()
    vim.cmd("edit " .. fn.fnameescape(target.source_file))
    pcall(api.nvim_win_set_cursor, 0, { target.source_line, 0 })
  end)
end

local function run_pack_action(action)
  if state.close_on_action then
    close()
    vim.schedule(action)
    return
  end

  vim.schedule(function()
    action()
    if state.wins.frame and api.nvim_win_is_valid(state.wins.frame) then
      vim.defer_fn(function()
        if state.wins.frame and api.nvim_win_is_valid(state.wins.frame) then
          pcall(refresh)
        end
      end, 120)
    end
  end)
end

local function update_selected(opts)
  local plugin = current_plugin()
  if not plugin then
    return
  end
  run_pack_action(function()
    vim.pack.update({ plugin.spec.name }, opts or {})
  end)
end

local function update_all(opts)
  run_pack_action(function()
    vim.pack.update(nil, opts or {})
  end)
end

local function delete_selected()
  local plugin = current_plugin()
  if not plugin then
    return
  end
  if plugin.active then
    vim.notify("Delete is limited to inactive plugins to avoid removing loaded code.", vim.log.levels.WARN)
    return
  end
  vim.ui.input({
    prompt = ("Delete %s from disk? Type yes to confirm: "):format(plugin.spec.name),
  }, function(input)
    if input ~= "yes" then
      vim.notify("Plugin deletion cancelled.", vim.log.levels.INFO)
      return
    end
    run_pack_action(function()
      vim.pack.del({ plugin.spec.name })
    end)
  end)
end

local function set_query()
  vim.ui.input({
    prompt = "Filter plugins: ",
    default = state.query,
  }, function(input)
    if input == nil then
      return
    end
    state.query = trim(input)
    refresh()
  end)
end

local function toggle_active_only()
  state.active_only = not state.active_only
  refresh()
end

local function move_selection(delta)
  if #state.filtered == 0 then
    return
  end
  state.selection = math.max(1, math.min(#state.filtered, state.selection + delta))
  render_list()
  render_detail()
  update_statusline()
end

local function set_tab(tab)
  state.tab = tab
  render_detail()
  update_statusline()
end

local function toggle_close_on_action()
  state.close_on_action = not state.close_on_action
  update_statusline()
  local mode = state.close_on_action and "close after action" or "stay open after action"
  vim.notify("Pack manager action mode: " .. mode, vim.log.levels.INFO)
end

local function open_repo()
  local plugin = current_plugin()
  if not plugin or not plugin.spec.src then
    vim.notify("No repository URL found for this plugin.", vim.log.levels.WARN)
    return
  end
  local ok = vim.ui.open(plugin.spec.src)
  if ok == false then
    vim.notify("Could not open repository URL.", vim.log.levels.WARN)
  end
end

local function show_help()
  local lines = {
    " Pack Manager Keys ",
    "",
    " j / k / <Down> / <Up>   move selection",
    " <CR> or <Tab>           focus detail pane",
    " <S-Tab>                 focus plugin list",
    " r                       refresh data from vim.pack.get()",
    " /                       set text filter",
    " a                       toggle active-only mode",
    " 1 / 2 / 3               switch tabs (Details / Update / Check)",
    " p                       toggle close-on-action mode",
    " u                       update selected plugin",
    " U                       update all plugins",
    " O                       open offline update review for selected plugin",
    " L                       sync selected plugin to lockfile target",
    " e                       open matching config file",
    " o                       open plugin repository URL",
    " x                       delete selected inactive plugin",
    " q / <Esc>               close manager",
    "",
    " Notes ",
    " vim.pack update review opens in Neovim's native confirmation tab.",
    " This UI reads your lua/plugins/*.lua files to show config context.",
    " Messages and prompts are designed to work nicely with your enabled ui2.",
  }

  local buf = require("custom.ui.buffer").create_raw(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_opt(buf, "buftype", "nofile")
  set_buf_opt(buf, "bufhidden", "wipe")
  set_buf_opt(buf, "modifiable", false)

  local width = 74
  local height = #lines
  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2)),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Pack Manager Help ",
    title_pos = "center",
  })

  vim.wo[win].winhl = "Normal:PackManagerNormal,FloatBorder:PackManagerBorder,FloatTitle:PackManagerTitle"
  set_win_opt(win, "wrap", false)
  nvim_utils.bind_close_keys(buf, win, { "q", "<Esc>", "?" }, { silent = true, nowait = true })
end

local function attach_keymaps()
  local list_buf = state.bufs.list
  local detail_buf = state.bufs.detail
  local frame_win = state.wins.frame

  local close_all = function()
    close()
  end

  local maps = {
    { "q", close_all, "Close" },
    { "<Esc>", close_all, "Close" },
    { "j", function() move_selection(1) end, "Next plugin" },
    { "k", function() move_selection(-1) end, "Previous plugin" },
    { "<Down>", function() move_selection(1) end, "Next plugin" },
    { "<Up>", function() move_selection(-1) end, "Previous plugin" },
    { "r", refresh, "Refresh" },
    { "/", set_query, "Filter" },
    { "a", toggle_active_only, "Active only" },
    { "1", function() set_tab("details") end, "Details tab" },
    { "2", function() set_tab("update") end, "Update tab" },
    { "3", function() set_tab("check") end, "Check tab" },
    { "p", toggle_close_on_action, "Toggle close on action" },
    { "u", function() update_selected() end, "Update selected" },
    { "U", function() update_all() end, "Update all" },
    { "O", function() update_selected({ offline = true }) end, "Offline review" },
    { "L", function() update_selected({ offline = true, target = "lockfile" }) end, "Lockfile sync" },
    { "e", open_config, "Open config" },
    { "o", open_repo, "Open repo" },
    { "x", delete_selected, "Delete inactive plugin" },
    { "<CR>", focus_detail, "Focus detail" },
    { "<Tab>", focus_detail, "Focus detail" },
    { "?", show_help, "Help" },
  }

  for _, spec in ipairs(maps) do
    nvim_utils.buf_map(list_buf, "n", spec[1], spec[2], { silent = true, nowait = true, desc = spec[3] })
    nvim_utils.buf_map(detail_buf, "n", spec[1], spec[2], { silent = true, nowait = true, desc = spec[3] })
  end

  nvim_utils.buf_map(detail_buf, "n", "<S-Tab>", focus_list, { silent = true, nowait = true, desc = "Focus list" })
  nvim_utils.buf_map(list_buf, "n", "<S-Tab>", focus_list, { silent = true, nowait = true, desc = "Focus list" })

  api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if frame_win and api.nvim_win_is_valid(frame_win) then
        resize()
      end
    end,
  })
end

function M.open()
  if state.wins.frame and api.nvim_win_is_valid(state.wins.frame) then
    focus_list()
    refresh()
    return
  end

  setup_highlights()
  state.augroup = nvim_utils.augroup("custom_pack_manager_runtime", { clear = true })

  local frame_buf = require("custom.ui.buffer").create_raw(false, true)
  local list_buf = require("custom.ui.buffer").create_raw(false, true)
  local detail_buf = require("custom.ui.buffer").create_raw(false, true)

  state.bufs = {
    frame = frame_buf,
    list = list_buf,
    detail = detail_buf,
  }

  set_buf_opt(frame_buf, "buftype", "nofile")
  set_buf_opt(frame_buf, "bufhidden", "wipe")
  set_buf_opt(frame_buf, "modifiable", false)

  set_buf_opt(list_buf, "buftype", "nofile")
  set_buf_opt(list_buf, "bufhidden", "wipe")
  set_buf_opt(list_buf, "modifiable", false)
  set_buf_opt(list_buf, "filetype", "pack-manager-list")

  set_buf_opt(detail_buf, "buftype", "nofile")
  set_buf_opt(detail_buf, "bufhidden", "wipe")
  set_buf_opt(detail_buf, "modifiable", false)
  set_buf_opt(detail_buf, "filetype", "pack-manager-detail")

  local frame_win = require("custom.ui.window").open_raw(frame_buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = math.max(90, math.floor(vim.o.columns * 0.88)),
    height = math.max(26, math.floor(vim.o.lines * 0.82)),
    style = "minimal",
    border = "rounded",
    title = TITLE,
    title_pos = "center",
  })
  local list_win = require("custom.ui.window").open_raw(list_buf, true, {
    relative = "win",
    win = frame_win,
    row = 1,
    col = 1,
    width = 34,
    height = 20,
    style = "minimal",
    border = "none",
  })
  local detail_win = require("custom.ui.window").open_raw(detail_buf, false, {
    relative = "win",
    win = frame_win,
    row = 1,
    col = 36,
    width = math.max(40, math.floor(vim.o.columns * 0.5)),
    height = 20,
    style = "minimal",
    border = "none",
  })

  state.wins = {
    frame = frame_win,
    list = list_win,
    detail = detail_win,
  }

  vim.wo[frame_win].winhl = "Normal:PackManagerNormal,FloatBorder:PackManagerBorder,FloatTitle:PackManagerTitle"
  vim.wo[list_win].winhl = "Normal:PackManagerNormal,CursorLine:PackManagerCursor"
  vim.wo[detail_win].winhl = "Normal:PackManagerNormal"

  set_win_opt(frame_win, "winblend", 0)
  set_win_opt(list_win, "cursorline", true)
  set_win_opt(list_win, "number", false)
  set_win_opt(list_win, "relativenumber", false)
  set_win_opt(list_win, "wrap", false)
  set_win_opt(detail_win, "number", false)
  set_win_opt(detail_win, "relativenumber", false)
  set_win_opt(detail_win, "wrap", false)

  resize()
  attach_keymaps()
  refresh()
  focus_list()
end

function M.setup()
  vim.api.nvim_create_user_command("PackManager", function()
    require("custom.pack_manager").open()
  end, { desc = "Open vim.pack manager" })

  vim.keymap.set("n", "<leader>pp", function()
    M.open()
  end, { desc = "Pack manager" })

  vim.api.nvim_create_autocmd({ "PackChanged", "PackChangedPre" }, {
    group = vim.api.nvim_create_augroup("custom_pack_manager_sync", { clear = true }),
    callback = function()
      if state.wins.frame and api.nvim_win_is_valid(state.wins.frame) then
        vim.schedule(refresh)
      end
    end,
  })
end

return M
