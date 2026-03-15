-- custom/notifier/renderer.lua
-- Supports: group_append (Feature #3), refresh_timer (Feature #2 dedup)

local M = {}

local _cfg    = nil
local _active = {}  -- { id, win, buf, height, width, notif, timers, group_count }

local ns = vim.api.nvim_create_namespace("notifier_renderer")

-- ─────────────────────────────────────────────────────────────────
-- Level tables
-- ─────────────────────────────────────────────────────────────────

local LEVEL_STR = {
  [vim.log.levels.ERROR] = "ERROR",
  [vim.log.levels.WARN]  = "WARN",
  [vim.log.levels.INFO]  = "INFO",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.TRACE] = "TRACE",
}
local COLORS = {
  ERROR = { fg = "#f38ba8", bg = "#2a1520", border = "#f38ba8" },
  WARN  = { fg = "#fab387", bg = "#2a1e14", border = "#fab387" },
  INFO  = { fg = "#89b4fa", bg = "#141e2a", border = "#89b4fa" },
  DEBUG = { fg = "#a6e3a1", bg = "#142a18", border = "#a6e3a1" },
  TRACE = { fg = "#cba6f7", bg = "#1e142a", border = "#cba6f7" },
}
local ICONS = { ERROR=" ", WARN=" ", INFO=" ", DEBUG=" ", TRACE="󰓤 " }

local function lvl_str(level)
  if type(level) == "string" then return level:upper() end
  return LEVEL_STR[level] or "INFO"
end

-- ─────────────────────────────────────────────────────────────────
-- Highlights (idempotent)
-- ─────────────────────────────────────────────────────────────────

local _hl_init = false
local function ensure_highlights()
  if _hl_init then return end
  _hl_init = true
  local set = vim.api.nvim_set_hl
  for lvl, c in pairs(COLORS) do
    set(0, "NotifierTitleBg" .. lvl, { default = true, bg = c.bg, fg = c.fg, bold = true })
    set(0, "NotifierAccent"  .. lvl, { default = true, bg = c.fg, fg = c.fg })
    set(0, "NotifierBorder"  .. lvl, { default = true, fg = c.border })
    set(0, "NotifierProgress".. lvl, { default = true, fg = c.fg })
    set(0, "NotifierBadge"   .. lvl, { default = true, bg = c.fg, fg = c.bg, bold = true })
  end
  set(0, "NotifierTime",  { default = true, fg = "#585b70" })
  set(0, "NotifierBody",  { default = true, link = "Normal" })
  set(0, "NotifierDim",   { default = true, fg = "#6c7086" })
  set(0, "NotifierBadgeBg",{ default = true, bg = "#313244", fg = "#cdd6f4", bold = true })
end

function M.set_config(cfg)
  _cfg = cfg
  ensure_highlights()
end

-- ─────────────────────────────────────────────────────────────────
-- Config helper
-- ─────────────────────────────────────────────────────────────────

local function get_cfg()
  return _cfg or {
    position = "top_right", max_width = 60, min_width = 32,
    border = "rounded", winblend = 5, gap = 1, fps = 30,
    animate = true, timeout = 4000, max_visible = 5,
  }
end

-- ─────────────────────────────────────────────────────────────────
-- Geometry
-- ─────────────────────────────────────────────────────────────────

local function anchor_and_pos(win_h, win_w, offset)
  local cfg = get_cfg()
  local pos = cfg.position or "top_right"
  local m   = 1
  local row, col, anchor
  if     pos == "top_right"     then row = m + offset;                            col = vim.o.columns - m; anchor = "NE"
  elseif pos == "top_left"      then row = m + offset;                            col = m;                 anchor = "NW"
  elseif pos == "bottom_right"  then row = vim.o.lines - m - win_h - offset;      col = vim.o.columns - m; anchor = "SE"
  elseif pos == "bottom_left"   then row = vim.o.lines - m - win_h - offset;      col = m;                 anchor = "SW"
  elseif pos == "top_center"    then row = m + offset; col = math.floor((vim.o.columns - win_w) / 2); anchor = "NW"
  elseif pos == "bottom_center" then row = vim.o.lines - m - win_h - offset;
                                      col = math.floor((vim.o.columns - win_w) / 2); anchor = "SW"
  else row = m + offset; col = vim.o.columns - m; anchor = "NE"
  end
  return row, col, anchor
end

-- ─────────────────────────────────────────────────────────────────
-- Text helpers
-- ─────────────────────────────────────────────────────────────────

local function wrap_text(msg, width)
  local out = {}
  for _, raw in ipairs(vim.split(tostring(msg), "\n", { plain = true })) do
    if raw == "" then
      table.insert(out, "")
    else
      local r = raw
      while #r > width do
        local cut = r:sub(1, width)
        local sp  = cut:match("^.*()%s") or width
        table.insert(out, r:sub(1, sp):gsub("%s+$", ""))
        r = r:sub(sp + 1)
      end
      if #r > 0 then table.insert(out, r) end
    end
  end
  return out
end

local function progress_bar(pct, width)
  if not pct or pct == false then return nil end
  if pct == true or pct == nil then
    local sp = { "⣾","⣽","⣻","⢿","⡿","⣟","⣯","⣷" }
    return sp[math.floor(vim.loop.now() / 100) % #sp + 1] .. " Working…"
  end
  local f = math.floor((pct / 100) * width)
  return string.rep("█", f) .. string.rep("░", width - f)
    .. string.format(" %d%%", pct)
end

-- ─────────────────────────────────────────────────────────────────
-- Build buffer content
-- ─────────────────────────────────────────────────────────────────

local GUTTER = "▎ "

local function build_content(notif, inner_w, group_count)
  local lvl  = lvl_str(notif.level)
  local icon = ((_cfg and _cfg.icons) or ICONS)[lvl] or " "
  local src  = notif.title or ""
  local ts   = os.date("%H:%M")
  -- group count badge: " (3)" shown after source
  local badge = (group_count and group_count > 1)
    and string.format(" (%d)", group_count) or ""
  local src_w = inner_w - #icon - #ts - #badge - 4
  if #src > src_w then src = src:sub(1, src_w - 1) .. "…" end
  local filler = string.rep(" ", math.max(1, inner_w - #icon - #src - #badge - #ts - 2))
  local title_line = GUTTER .. icon .. src .. badge .. filler .. ts

  local msg = type(notif.message) == "table"
    and table.concat(notif.message, "\n") or tostring(notif.message)
  local body_lines = wrap_text(msg, inner_w - 2)

  local lines = { title_line }
  for _, l in ipairs(body_lines) do
    table.insert(lines, GUTTER .. " " .. l)
  end

  local pb = progress_bar(notif.progress, inner_w - 8)
  if pb then table.insert(lines, GUTTER .. " " .. pb) end

  return lines, lvl
end

-- ─────────────────────────────────────────────────────────────────
-- Highlights on buffer
-- ─────────────────────────────────────────────────────────────────

local function apply_highlights(buf, lines, lvl, group_count)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local hl_t = "NotifierTitleBg" .. lvl
  local hl_a = "NotifierAccent"  .. lvl
  local hl_p = "NotifierProgress".. lvl
  local hl_b = "NotifierBadge"   .. lvl

  for i, line in ipairs(lines) do
    local row = i - 1
    if row == 0 then
      vim.api.nvim_buf_add_highlight(buf, ns, hl_t, row, 0, -1)
      vim.api.nvim_buf_add_highlight(buf, ns, hl_a, row, 0, 3)
      -- timestamp: last 5 chars
      if #line > 5 then
        vim.api.nvim_buf_add_highlight(buf, ns, "NotifierTime", row, #line - 5, -1)
      end
      -- group count badge highlight
      if group_count and group_count > 1 then
        local badge = string.format(" (%d)", group_count)
        local ts_start = #line - 5
        local badge_end = ts_start
        local badge_start = badge_end - #badge
        if badge_start > 3 then
          vim.api.nvim_buf_add_highlight(buf, ns, hl_b, row, badge_start, badge_end)
        end
      end
    else
      vim.api.nvim_buf_add_highlight(buf, ns, hl_a,          row, 0, 3)
      vim.api.nvim_buf_add_highlight(buf, ns, "NotifierBody", row, 3, -1)
    end
    if line:match("█") then
      local fill_end = select(2, line:gsub("█", "")) * 3 + 3
      vim.api.nvim_buf_add_highlight(buf, ns, hl_p, row, 3, fill_end)
      vim.api.nvim_buf_add_highlight(buf, ns, "NotifierDim", row, fill_end, -1)
    end
  end
end

-- ─────────────────────────────────────────────────────────────────
-- Timer management
-- ─────────────────────────────────────────────────────────────────

local function cancel_timers(rec)
  for _, t in ipairs(rec.timers or {}) do
    if t and not t:is_closing() then
      pcall(function() t:stop(); t:close() end)
    end
  end
  rec.timers = {}
end

local function start_fade(rec)
  local cfg  = get_cfg()
  local win  = rec.win
  local step = math.max(1, math.floor(1000 / (cfg.fps or 30)))
  local t    = vim.loop.new_timer()
  table.insert(rec.timers, t)
  t:start(0, step, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(win) then
      pcall(function() t:stop(); t:close() end); return
    end
    pcall(function()
      local b = vim.api.nvim_win_get_option(win, "winblend")
      b = b + 10
      if b >= 100 then
        pcall(function() t:stop(); t:close() end)
        M.close(rec.id)
      else
        vim.api.nvim_win_set_option(win, "winblend", b)
      end
    end)
  end))
end

local function start_slide(rec, target_col, target_row, anchor)
  local cfg     = get_cfg()
  local win     = rec.win
  local steps   = 8
  local step_ms = math.floor(1000 / (cfg.fps or 30))
  local cur     = 0
  local start_col = vim.o.columns + 4
  local t = vim.loop.new_timer()
  table.insert(rec.timers, t)
  t:start(0, step_ms, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(win) then
      pcall(function() t:stop(); t:close() end); return
    end
    cur = cur + 1
    local ease = 1 - math.pow(1 - cur / steps, 3)
    local col  = math.floor(start_col + (target_col - start_col) * ease)
    pcall(vim.api.nvim_win_set_config, win, {
      relative = "editor", row = target_row, col = col, anchor = anchor,
    })
    if cur >= steps then pcall(function() t:stop(); t:close() end) end
  end))
end

local function arm_timeout(rec, timeout)
  if not (timeout and timeout > 0) then return end
  local cfg        = get_cfg()
  local fade_after = math.max(0, timeout - 600)

  local t_fade = vim.loop.new_timer()
  table.insert(rec.timers, t_fade)
  t_fade:start(fade_after, 0, vim.schedule_wrap(function()
    pcall(function() t_fade:stop(); t_fade:close() end)
    if vim.api.nvim_win_is_valid(rec.win) and cfg.animate then
      start_fade(rec)
    end
  end))

  local t_close = vim.loop.new_timer()
  table.insert(rec.timers, t_close)
  t_close:start(timeout, 0, vim.schedule_wrap(function()
    pcall(function() t_close:stop(); t_close:close() end)
    M.close(rec.id)
  end))
end

-- ─────────────────────────────────────────────────────────────────
-- Remove + restack
-- ─────────────────────────────────────────────────────────────────

local function remove_record(id)
  for i, rec in ipairs(_active) do
    if rec.id == id then table.remove(_active, i); break end
  end
  M.restack()
end

function M.restack()
  local cfg    = get_cfg()
  local gap    = cfg.gap or 1
  local offset = 0
  for _, rec in ipairs(_active) do
    if not vim.api.nvim_win_is_valid(rec.win) then goto continue end
    local row, col, anchor = anchor_and_pos(rec.height, rec.width, offset)
    pcall(vim.api.nvim_win_set_config, rec.win, {
      relative = "editor", row = row, col = col, anchor = anchor,
    })
    offset = offset + rec.height + gap
    ::continue::
  end
end

-- ─────────────────────────────────────────────────────────────────
-- Close
-- ─────────────────────────────────────────────────────────────────

function M.close(id)
  for _, rec in ipairs(_active) do
    if rec.id == id then
      cancel_timers(rec)
      if vim.api.nvim_win_is_valid(rec.win) then
        vim.api.nvim_win_close(rec.win, true)
      end
      if vim.api.nvim_buf_is_valid(rec.buf) then
        pcall(vim.api.nvim_buf_delete, rec.buf, { force = true })
      end
      if rec.notif and rec.notif.on_close then
        pcall(rec.notif.on_close, rec.notif)
      end
      break
    end
  end
  remove_record(id)
end

function M.close_all()
  local ids = vim.tbl_map(function(r) return r.id end, _active)
  for _, id in ipairs(ids) do M.close(id) end
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #2: refresh_timer — reset countdown without re-rendering
-- ─────────────────────────────────────────────────────────────────

function M.refresh_timer(id, timeout)
  for _, rec in ipairs(_active) do
    if rec.id == id then
      cancel_timers(rec)
      arm_timeout(rec, timeout)
      -- also reset winblend in case fade had started
      if vim.api.nvim_win_is_valid(rec.win) then
        pcall(vim.api.nvim_win_set_option, rec.win, "winblend", get_cfg().winblend or 5)
      end
      return
    end
  end
end

-- ─────────────────────────────────────────────────────────────────
-- Feature #3: group_append — append a line to an existing group window
-- ─────────────────────────────────────────────────────────────────

function M.group_append(id, new_message)
  for _, rec in ipairs(_active) do
    if rec.id == id then
      rec.group_count = (rec.group_count or 1) + 1

      -- append the new message to notif.message (keep all lines)
      local existing = type(rec.notif.message) == "table"
        and table.concat(rec.notif.message, "\n") or tostring(rec.notif.message)
      local incoming = type(new_message) == "table"
        and table.concat(new_message, "\n") or tostring(new_message)
      rec.notif.message = existing .. "\n" .. incoming

      -- rebuild + resize
      local inner_w = (rec.width or 34) - 2
      local lines, lvl = build_content(rec.notif, inner_w, rec.group_count)

      if #lines ~= (rec.height - 2) then
        rec.height = #lines + 2
        if vim.api.nvim_win_is_valid(rec.win) then
          pcall(vim.api.nvim_win_set_config, rec.win, { height = #lines })
        end
        M.restack()
      end

      if vim.api.nvim_buf_is_valid(rec.buf) then
        vim.api.nvim_buf_set_option(rec.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(rec.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(rec.buf, "modifiable", false)
        apply_highlights(rec.buf, lines, lvl, rec.group_count)
      end

      -- reset dismiss timer so grouped message stays visible
      cancel_timers(rec)
      arm_timeout(rec, rec.notif.timeout)
      return
    end
  end
end

-- ─────────────────────────────────────────────────────────────────
-- Render
-- ─────────────────────────────────────────────────────────────────

function M.render(notif)
  ensure_highlights()
  local cfg = get_cfg()

  while #_active >= (cfg.max_visible or 5) do M.close(_active[1].id) end
  if cfg.suppress_in_insert and vim.fn.mode() == "i" then return end
  if notif.replace_id then M.close(notif.replace_id) end

  local lvl     = lvl_str(notif.level)
  local max_w   = math.min(cfg.max_width or 60, vim.o.columns - 4)
  local inner_w = math.max(cfg.min_width or 32, max_w)
  local win_w   = inner_w + 2

  local lines, _ = build_content(notif, inner_w, 1)
  local win_h    = #lines

  -- Stack offset
  local offset = 0
  for _, rec in ipairs(_active) do
    if vim.api.nvim_win_is_valid(rec.win) then
      offset = offset + rec.height + (cfg.gap or 1)
    end
  end

  local target_row, target_col, anchor = anchor_and_pos(win_h + 2, win_w, offset)
  local initial_col = cfg.animate and (vim.o.columns + 4) or target_col

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "notifier")

  local win = vim.api.nvim_open_win(buf, false, {
    relative  = "editor",
    row       = target_row,
    col       = initial_col,
    width     = win_w,
    height    = win_h,
    anchor    = anchor,
    style     = "minimal",
    border    = cfg.border or "rounded",
    focusable = false,
    zindex    = 100,
  })

  local hl_border = "NotifierBorder" .. lvl
  vim.api.nvim_win_set_option(win, "winhighlight",
    "Normal:Normal,NormalFloat:Normal,FloatBorder:" .. hl_border)
  vim.api.nvim_win_set_option(win, "winblend",        cfg.winblend or 5)
  vim.api.nvim_win_set_option(win, "wrap",            false)
  vim.api.nvim_win_set_option(win, "cursorline",      false)
  vim.api.nvim_win_set_option(win, "number",          false)
  vim.api.nvim_win_set_option(win, "relativenumber",  false)
  vim.api.nvim_win_set_option(win, "signcolumn",      "no")

  apply_highlights(buf, lines, lvl, 1)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true, silent = true,
    callback = function() M.close(notif.id) end,
  })

  local rec = {
    id          = notif.id,
    win         = win,
    buf         = buf,
    height      = win_h + 2,
    width       = win_w,
    notif       = notif,
    timers      = {},
    group_count = 1,
  }
  table.insert(_active, rec)

  if cfg.animate then start_slide(rec, target_col, target_row, anchor) end
  arm_timeout(rec, notif.timeout)

  if notif.on_open then pcall(notif.on_open, notif) end
end

-- ─────────────────────────────────────────────────────────────────
-- Update in-place
-- ─────────────────────────────────────────────────────────────────

function M.update(id, new_msg, new_level, new_progress)
  for _, rec in ipairs(_active) do
    if rec.id == id then
      if new_msg      ~= nil then rec.notif.message  = new_msg      end
      if new_level    ~= nil then rec.notif.level    = new_level    end
      if new_progress ~= nil then rec.notif.progress = new_progress end

      local inner_w = (rec.width or 34) - 2
      local lines, lvl = build_content(rec.notif, inner_w, rec.group_count)

      if #lines ~= (rec.height - 2) then
        rec.height = #lines + 2
        if vim.api.nvim_win_is_valid(rec.win) then
          pcall(vim.api.nvim_win_set_config, rec.win, { height = #lines })
        end
        M.restack()
      end

      if vim.api.nvim_buf_is_valid(rec.buf) then
        vim.api.nvim_buf_set_option(rec.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(rec.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(rec.buf, "modifiable", false)
        apply_highlights(rec.buf, lines, lvl, rec.group_count)
      end
      return
    end
  end
end

function M.active()
  local out = {}
  for _, rec in ipairs(_active) do
    if vim.api.nvim_win_is_valid(rec.win) then
      table.insert(out, { id = rec.id, notif = rec.notif, group_count = rec.group_count })
    end
  end
  return out
end

return M
