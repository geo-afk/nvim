-- custom/notifier/init.lua
-- Features: routing/filters, dedup, grouping, per-level timeouts,
--           min-level filter, snooze/pause, Telescope integration.

local M = {}

-- ─────────────────────────────────────────────────────────────────
-- Highlights (inlined)
-- ─────────────────────────────────────────────────────────────────

local function setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, 'NotifyError', { default = true, fg = '#f38ba8', bold = true })
  hl(0, 'NotifyWarn', { default = true, fg = '#fab387', bold = true })
  hl(0, 'NotifyInfo', { default = true, fg = '#89b4fa', bold = true })
  hl(0, 'NotifyDebug', { default = true, fg = '#a6e3a1' })
  hl(0, 'NotifyTrace', { default = true, fg = '#cba6f7' })
  hl(0, 'NotifyTitle', { default = true, fg = '#cdd6f4', bold = true })
  hl(0, 'NotifyBody', { default = true, link = 'Normal' })
  hl(0, 'NotifyBorder', { default = true, fg = '#45475a' })
  hl(0, 'NotifyHistoryTitle', { default = true, link = 'Title' })
  hl(0, 'NotifyHistorySep', { default = true, link = 'Comment' })
end

-- ─────────────────────────────────────────────────────────────────
-- History (inlined)
-- ─────────────────────────────────────────────────────────────────

local _history = {}
local _max_history = 100

local function history_push(notif)
  local msg = type(notif.message) == 'table' and table.concat(notif.message, '\n') or tostring(notif.message)
  table.insert(_history, 1, {
    id = notif.id,
    message = msg,
    level = notif.level,
    title = notif.title,
    time_str = os.date '%H:%M:%S',
    date_str = os.date '%Y-%m-%d',
  })
  if #_history > _max_history then
    table.remove(_history)
  end
end

local function lvl_to_str(level)
  local t = {
    [vim.log.levels.ERROR] = 'ERROR',
    [vim.log.levels.WARN] = 'WARN',
    [vim.log.levels.INFO] = 'INFO',
    [vim.log.levels.DEBUG] = 'DEBUG',
    [vim.log.levels.TRACE] = 'TRACE',
  }
  if type(level) == 'string' then
    return level:upper()
  end
  return t[level] or 'INFO'
end

local function history_show(opts)
  opts = opts or {}
  local items = _history
  if opts.level then
    local want = type(opts.level) == 'string' and opts.level:upper() or lvl_to_str(opts.level)
    items = vim.tbl_filter(function(n)
      return lvl_to_str(n.level) == want
    end, items)
  end
  if opts.source then
    items = vim.tbl_filter(function(n)
      return n.title == opts.source
    end, items)
  end
  if opts.find then
    items = vim.tbl_filter(function(n)
      return n.message:find(opts.find, 1, true)
    end, items)
  end

  if #items == 0 then
    vim.notify('[notifier] No matching history entries.', vim.log.levels.INFO)
    return
  end

  -- Sort support: "time" (default newest-first) or "level"
  if opts.sort == 'level' then
    local order = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4, TRACE = 5 }
    table.sort(items, function(a, b)
      return (order[lvl_to_str(a.level)] or 9) < (order[lvl_to_str(b.level)] or 9)
    end)
  end

  local icons = { ERROR = ' ', WARN = ' ', INFO = ' ', DEBUG = ' ', TRACE = '󰓤 ' }
  local hls = { ERROR = 'NotifyError', WARN = 'NotifyWarn', INFO = 'NotifyInfo', DEBUG = 'NotifyDebug', TRACE = 'NotifyTrace' }

  local lines, hl_data = {}, {}
  table.insert(lines, string.format('  Notification History  (%d entries)', #items))
  table.insert(lines, string.rep('─', 64))

  for i, n in ipairs(items) do
    local lvl = lvl_to_str(n.level)
    local icon = icons[lvl] or ' '
    local hl = hls[lvl] or 'NotifyInfo'
    local src = n.title and ('[' .. n.title .. '] ') or ''
    local ts = n.date_str and (n.date_str .. ' ' .. n.time_str) or n.time_str
    local line = string.format(' %s %s %s%s', ts, icon, src, n.message)
    local icon_col = #(' ' .. ts .. ' ')
    table.insert(hl_data, { #lines, icon_col, icon_col + #icon, hl })
    for _, ml in ipairs(vim.split(line, '\n', { plain = true })) do
      table.insert(lines, ml)
    end
    if i < #items then
      table.insert(lines, '')
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  local ns = vim.api.nvim_create_namespace 'notifier_history_view'
  vim.api.nvim_buf_add_highlight(buf, ns, 'NotifyHistoryTitle', 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, 'NotifyHistorySep', 1, 0, -1)
  for _, h in ipairs(hl_data) do
    vim.api.nvim_buf_add_highlight(buf, ns, h[4], h[1], h[2], h[3])
  end

  local width = math.min(88, vim.o.columns - 4)
  local height = math.min(#lines, math.floor(vim.o.lines * 0.7))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = '  Notification History ',
    title_pos = 'center',
  })
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  vim.api.nvim_win_set_option(win, 'wrap', false)

  -- Keymaps: q/Esc close; s sort-by-level; f filter prompt
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', { noremap = true, silent = true, callback = close })
  end
  -- s: re-open sorted by level
  vim.api.nvim_buf_set_keymap(buf, 'n', 's', '', {
    noremap = true,
    silent = true,
    callback = function()
      close()
      history_show(vim.tbl_extend('force', opts, { sort = 'level' }))
    end,
  })
  -- f: filter by source prompt
  vim.api.nvim_buf_set_keymap(buf, 'n', 'f', '', {
    noremap = true,
    silent = true,
    callback = function()
      close()
      vim.ui.input({ prompt = 'Filter source: ' }, function(src)
        if src and src ~= '' then
          history_show(vim.tbl_extend('force', opts, { source = src }))
        else
          history_show(opts)
        end
      end)
    end,
  })
  -- /: filter by text
  vim.api.nvim_buf_set_keymap(buf, 'n', '/', '', {
    noremap = true,
    silent = true,
    callback = function()
      close()
      vim.ui.input({ prompt = 'Search text: ' }, function(pat)
        if pat and pat ~= '' then
          history_show(vim.tbl_extend('force', opts, { find = pat }))
        else
          history_show(opts)
        end
      end)
    end,
  })
end

-- ─────────────────────────────────────────────────────────────────
-- Default config
-- ─────────────────────────────────────────────────────────────────

local defaults = {
  -- Global timeout (ms). 0 = never auto-dismiss.
  timeout = 4000,

  -- Per-level timeouts (override global). nil = use global.
  -- Feature #5: per-level timeout overrides
  timeouts = {
    ERROR = 0, -- errors stay until dismissed
    WARN = 8000,
    INFO = 4000,
    DEBUG = 2000,
    TRACE = 2000,
  },

  -- Feature #6: global minimum level filter. Anything below this is dropped.
  -- vim.log.levels.TRACE=0, DEBUG=1, INFO=2, WARN=3, ERROR=4
  min_level = vim.log.levels.TRACE,

  -- Feature #7: start in paused/snooze mode
  paused = false,

  -- Feature #1: routing rules (evaluated in order, first match wins).
  -- Each rule: { filter={...}, opts={skip, timeout, level, title} }
  --   filter keys: find (string pattern), level, source (title), min_height (line count)
  --   opts keys:   skip=true to suppress, timeout=N to override, title="…" to rename
  -- Example:
  --   routes = {
  --     { filter = { find = "No information available" }, opts = { skip = true } },
  --     { filter = { source = "null-ls" },               opts = { skip = true } },
  --     { filter = { level = vim.log.levels.ERROR },     opts = { timeout = 0  } },
  --   }
  routes = {},

  -- Feature #3: grouping — collapse same-source notifications into one window
  -- "source" = group by notif.title; "content_key" = group by dedup key
  group_by = 'source', -- "source" | "none"

  -- Feature #2: deduplication — if same content_key is active, update in-place
  deduplicate = true,

  -- Per-source ignore list (shorthand for a skip route)
  ignore = {},

  max_visible = 5,
  max_history = 100,
  position = 'top_right',
  min_width = 30,
  max_width = 60,
  border = 'rounded',
  winblend = 5,
  animate = true,
  fps = 30,
  padding = { top = 0, right = 1, bottom = 0, left = 1 },
  gap = 1,
  icons = { ERROR = ' ', WARN = ' ', INFO = ' ', DEBUG = ' ', TRACE = '󰓤 ' },
  replace_vim_notify = true,
  lsp_progress = true,
  suppress_in_insert = false,
  on_open = nil,
  on_close = nil,
}

local function build_config(opts)
  opts = opts or {}
  local cfg = vim.deepcopy(defaults)
  for k, v in pairs(opts) do
    if type(v) == 'table' and type(cfg[k]) == 'table' and k ~= 'routes' and k ~= 'ignore' then
      cfg[k] = vim.tbl_extend('force', cfg[k], v)
    else
      cfg[k] = v
    end
  end
  return cfg
end

-- ─────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────

local _cfg = nil
local _id_seq = 0
local _orig_notify = vim.notify
local _paused = false -- Feature #7
local _pause_queue = {} -- queued while paused
-- Feature #2: dedup table  content_key -> active notification id
local _dedup_keys = {}
-- Feature #3: group table  group_key -> active notification id
local _groups = {}

local function gen_id()
  _id_seq = _id_seq + 1
  return 'notif_' .. _id_seq
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #1: Routing
-- ─────────────────────────────────────────────────────────────────

-- Returns the matched route's opts table, or nil if no match / no routes.
local function apply_routes(notif)
  local cfg = _cfg or defaults
  local routes = cfg.routes or {}
  local msg = type(notif.message) == 'table' and table.concat(notif.message, '\n') or tostring(notif.message)

  for _, route in ipairs(routes) do
    local f = route.filter or {}
    local pass = true

    -- filter.find: plain-text or Lua pattern match against message
    if f.find ~= nil then
      pass = pass and (msg:find(f.find) ~= nil)
    end
    -- filter.source: match notif.title
    if f.source ~= nil then
      pass = pass and (notif.title == f.source)
    end
    -- filter.level: exact level match
    if f.level ~= nil then
      local want = type(f.level) == 'number' and f.level or ({ ERROR = 4, WARN = 3, INFO = 2, DEBUG = 1, TRACE = 0 })[f.level:upper()]
      local got = type(notif.level) == 'number' and notif.level or ({ ERROR = 4, WARN = 3, INFO = 2, DEBUG = 1, TRACE = 0 })[lvl_to_str(notif.level)]
      pass = pass and (got == want)
    end
    -- filter.min_height: message line count must be >= N
    if f.min_height ~= nil then
      local lines = select(2, msg:gsub('\n', '')) + 1
      pass = pass and (lines >= f.min_height)
    end

    if pass then
      return route.opts or {}
    end
  end
  return nil
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #6: Min-level filter
-- ─────────────────────────────────────────────────────────────────

local LEVEL_NUM = { TRACE = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

local function below_min_level(level)
  local cfg = _cfg or defaults
  local min = cfg.min_level
  if min == nil or min == vim.log.levels.TRACE or min == 0 then
    return false
  end
  local got = type(level) == 'number' and level or (LEVEL_NUM[lvl_to_str(level)] or 2)
  local lim = type(min) == 'number' and min or (LEVEL_NUM[lvl_to_str(min)] or 0)
  return got < lim
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #5: Per-level timeout resolution
-- ─────────────────────────────────────────────────────────────────

local function resolve_timeout(notif)
  -- explicit per-notification timeout wins
  if notif.timeout ~= nil then
    return notif.timeout
  end
  local cfg = _cfg or defaults
  local lvl = lvl_to_str(notif.level)
  if cfg.timeouts and cfg.timeouts[lvl] ~= nil then
    return cfg.timeouts[lvl]
  end
  return cfg.timeout
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #2: Deduplication key
-- ─────────────────────────────────────────────────────────────────

local function content_key(notif)
  local msg = type(notif.message) == 'table' and table.concat(notif.message, '\n') or tostring(notif.message)
  return (notif.title or '') .. '|' .. lvl_to_str(notif.level) .. '|' .. msg
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #3: Group key
-- ─────────────────────────────────────────────────────────────────

local function group_key(notif)
  local cfg = _cfg or defaults
  if cfg.group_by == 'source' and notif.title then
    return 'grp|' .. notif.title
  end
  return nil
end

-- ─────────────────────────────────────────────────────────────────
-- Core render dispatch
-- ─────────────────────────────────────────────────────────────────

local function do_render(notif)
  local ok, renderer = pcall(require, 'custom.notifier.renderer')
  if not (ok and renderer.render) then
    return
  end

  local cfg = _cfg or defaults
  notif.timeout = resolve_timeout(notif)

  -- ── Feature #2: Deduplication ─────────────────────────────────
  if cfg.deduplicate then
    local ck = content_key(notif)
    local existing_id = _dedup_keys[ck]
    if existing_id then
      -- same content is already on screen — refresh its timer, done
      renderer.refresh_timer(existing_id, notif.timeout)
      return existing_id
    end
    -- register the key; clean it up when the notif closes
    _dedup_keys[ck] = notif.id
    local orig_close = notif.on_close
    notif.on_close = function(n)
      _dedup_keys[ck] = nil
      if orig_close then
        orig_close(n)
      end
    end
    notif._dedup_key = ck
  end

  -- ── Feature #3: Grouping ──────────────────────────────────────
  local gk = group_key(notif)
  if gk then
    local group_id = _groups[gk]
    if group_id and renderer.group_append then
      renderer.group_append(group_id, notif.message)
      return group_id
    end
    -- first of its group — register and clean up on close
    _groups[gk] = notif.id
    local orig_close2 = notif.on_close
    notif.on_close = function(n)
      if _groups[gk] == n.id then
        _groups[gk] = nil
      end
      if orig_close2 then
        orig_close2(n)
      end
    end
  end

  renderer.render(notif)
  return notif.id
end

-- ─────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────

function M.notify(message, level, opts)
  opts = opts or {}
  level = level or vim.log.levels.INFO

  -- Feature #6: min-level drop
  if below_min_level(level) then
    return nil
  end

  local cfg = _cfg or defaults

  -- Per-source ignore list (Feature shorthand)
  if opts.title and vim.tbl_contains(cfg.ignore or {}, opts.title) then
    return nil
  end

  -- Feature #1: routing
  local route_opts = apply_routes {
    message = message,
    level = level,
    title = opts.title,
  }
  if route_opts then
    if route_opts.skip then
      return nil
    end
    -- route can override timeout or level
    if route_opts.timeout ~= nil then
      opts.timeout = route_opts.timeout
    end
    if route_opts.level ~= nil then
      level = route_opts.level
    end
    if route_opts.title ~= nil then
      opts.title = route_opts.title
    end
  end

  local notif = {
    id = opts.id or gen_id(),
    message = message,
    level = level,
    title = opts.title,
    timeout = opts.timeout,
    replace_id = opts.replace_id,
    progress = opts.progress,
    on_open = opts.on_open or cfg.on_open,
    on_close = opts.on_close or cfg.on_close,
  }

  history_push(notif)

  -- Feature #7: if paused, queue and return
  if _paused then
    table.insert(_pause_queue, notif)
    return notif.id
  end

  return do_render(notif)
end

function M.dismiss(id)
  local ok, r = pcall(require, 'custom.notifier.renderer')
  if ok and r.close then
    r.close(id)
  end
  -- clean dedup / group state
  for k, v in pairs(_dedup_keys) do
    if v == id then
      _dedup_keys[k] = nil
    end
  end
  for k, v in pairs(_groups) do
    if v == id then
      _groups[k] = nil
    end
  end
end

function M.dismiss_all()
  local ok, r = pcall(require, 'custom.notifier.renderer')
  if ok and r.close_all then
    r.close_all()
  end
  _dedup_keys = {}
  _groups = {}
end

function M.update(id, message, level, progress)
  local ok, r = pcall(require, 'custom.notifier.renderer')
  if ok and r.update then
    r.update(id, message, level, progress)
  end
end

-- ── History ───────────────────────────────────────────────────────

---@param opts table|nil  { level, source, find, sort }
function M.show_history(opts)
  history_show(opts or {})
end
function M.get_history()
  return _history
end
function M.clear_history()
  _history = {}
end

-- ── Active ────────────────────────────────────────────────────────

function M.active()
  local ok, r = pcall(require, 'custom.notifier.renderer')
  return ok and r.active and r.active() or {}
end

-- ── Convenience shortcuts ─────────────────────────────────────────

function M.error(msg, opts)
  return M.notify(msg, vim.log.levels.ERROR, opts)
end
function M.warn(msg, opts)
  return M.notify(msg, vim.log.levels.WARN, opts)
end
function M.info(msg, opts)
  return M.notify(msg, vim.log.levels.INFO, opts)
end
function M.debug(msg, opts)
  return M.notify(msg, vim.log.levels.DEBUG, opts)
end

-- ── Feature #7: Snooze / Pause ───────────────────────────────────

--- Pause: queue all incoming notifications silently.
function M.pause()
  _paused = true
end

--- Resume: flush queued notifications.
function M.resume()
  _paused = false
  local q = _pause_queue
  _pause_queue = {}
  for _, notif in ipairs(q) do
    do_render(notif)
  end
end

--- Toggle pause state.
function M.toggle_pause()
  if _paused then
    M.resume()
  else
    M.pause()
  end
end

--- Returns true when paused.
function M.is_paused()
  return _paused
end

--- Return count of currently queued (paused) notifications.
function M.queued_count()
  return #_pause_queue
end

-- ── Feature #4: Telescope integration (lazy-loaded) ──────────────

--- Open the Telescope history picker.
--- No-ops with a friendly message if Telescope is not installed.
function M.telescope()
  local ok, _ = pcall(require, 'telescope')
  if not ok then
    vim.notify('[notifier] Telescope is not installed.', vim.log.levels.WARN)
    return
  end
  local t_ok, t_mod = pcall(require, 'custom.notifier.telescope')
  if t_ok and t_mod.pick then
    t_mod.pick()
  end
end

-- ── Statusline helper ─────────────────────────────────────────────

--- Returns a short string for statusline display.
--- Format: "ICON MSG" of the most recent notification.
function M.statusline()
  if #_history == 0 then
    return ''
  end
  local n = _history[1]
  local icons = { ERROR = ' ', WARN = ' ', INFO = ' ', DEBUG = ' ', TRACE = '󰓤 ' }
  local icon = icons[lvl_to_str(n.level)] or ' '
  local msg = n.message:match '^([^\n]+)' or n.message
  if #msg > 40 then
    msg = msg:sub(1, 38) .. '…'
  end
  return icon .. ' ' .. msg
end

-- ─────────────────────────────────────────────────────────────────
-- Setup
-- ─────────────────────────────────────────────────────────────────

function M.setup(opts)
  _cfg = build_config(opts)
  _max_history = _cfg.max_history
  _paused = _cfg.paused or false

  setup_highlights()

  local r_ok, renderer = pcall(require, 'custom.notifier.renderer')
  if r_ok and renderer.set_config then
    renderer.set_config(_cfg)
  end

  if _cfg.replace_vim_notify then
    vim.notify = function(message, level, o)
      return M.notify(message, level, o)
    end
  end

  if _cfg.lsp_progress then
    local l_ok, lsp = pcall(require, 'custom.notifier.lsp_progress')
    if l_ok and lsp.setup then
      lsp.setup()
    end
  end

  vim.api.nvim_create_autocmd('VimResized', {
    callback = function()
      local ok, r = pcall(require, 'custom.notifier.renderer')
      if ok and r.restack then
        r.restack()
      end
    end,
    group = vim.api.nvim_create_augroup('NotifyManagerResize', { clear = true }),
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      local ok, r = pcall(require, 'custom.notifier.renderer')
      if ok and r.close_all then
        r.close_all()
      end
    end,
    group = vim.api.nvim_create_augroup('NotifyManagerLeave', { clear = true }),
  })

  return M
end

-- Expose live config for runtime mutation
setmetatable(M, {
  __index = function(_, k)
    if k == '_cfg' then
      return _cfg
    end
  end,
})

function M.restore_vim_notify()
  vim.notify = _orig_notify
end

return M
