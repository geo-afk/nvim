-- lua/custom/loader/ui.lua
-- User-facing debug interface.
--
-- Commands registered:
--   :LoaderStats    — overview: states, queues, startup time, duplicates
--   :LoaderProfile  — per-module load times (requires profile=true)
--   :LoaderModules  — full module registry with state and timing
--   :LoaderReload   — force-reload a module (tab-completion supported)
--   :LoaderSlowmods — modules slower than N ms (default 5)
--
-- All reports open in a centred floating window.
-- Navigation: q / <Esc> to close.

local M = {}

local utils = require("custom.loader.utils")
local profiler = require("custom.loader.profiler")
local modules = require("custom.loader.modules")
local cache = require("custom.loader.cache")
local scheduler = require("custom.loader.scheduler")
local state = require("custom.loader.state")

-- ── Float window helper ───────────────────────────────────────────────────────

local function open_float(title, lines)
  local cols = vim.o.columns
  local rows = vim.o.lines
  local width = math.min(130, math.max(70, cols - 16))
  local height = math.min(50, math.max(8, #lines + 2))
  local row = math.floor((rows - height) / 2)
  local col = math.floor((cols - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "loader_report", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    noautocmd = true,
  })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, silent = true, nowait = true })
  end

  return buf, win
end

local HR = string.rep("─", 80)

-- ── :LoaderStats ─────────────────────────────────────────────────────────────

local function cmd_stats()
  local reg = modules.get_all()
  local counts = {}
  for _, s in pairs(modules.S) do
    counts[s] = 0
  end
  for _, spec in pairs(reg) do
    local s = modules.get_state(spec.mod)
    if counts[s] then
      counts[s] = counts[s] + 1
    end
  end

  local q = scheduler.get_queue_sizes()

  local lines = {
    "Loader Overview",
    HR,
    ("  Startup elapsed : %.1f ms"):format(profiler.elapsed_ms()),
    ("  Total load time : %.1f ms"):format(profiler.get_total_ms()),
    ("  Modules tracked : %d"):format(vim.tbl_count(reg)),
    "",
    "  Module states:",
    ("    ✓ loaded     : %d"):format(counts.loaded or 0),
    ("    ○ registered : %d"):format(counts.registered or 0),
    ("    ◌ pending    : %d"):format(counts.pending or 0),
    ("    ✗ failed     : %d"):format(counts.failed or 0),
    ("    ~ skipped    : %d"):format(counts.skipped or 0),
    "",
    "  Queues:",
    ("    deferred  : %d"):format(q.deferred),
    ("    idle      : %d"):format(q.idle),
  }

  local dupes = cache.get_duplicates()
  if #dupes > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  Duplicate loads detected:"
    for _, d in ipairs(dupes) do
      lines[#lines + 1] = ("    %-60s ×%d"):format(utils.trunc(d.mod, 60), d.count)
    end
  end

  open_float("Loader Stats", lines)
end

-- ── :LoaderProfile ────────────────────────────────────────────────────────────

local function cmd_profile()
  local timings = profiler.get_all()
  local lines = {
    "Load Time Profile  (requires: loader.setup({ profile = true }))",
    HR,
    ("  %-58s %10s"):format("Module", "ms"),
    HR,
  }

  for _, t in ipairs(timings) do
    local bar = string.rep("█", math.min(18, math.ceil(t.duration_ms / 2)))
    lines[#lines + 1] = ("  %-58s %8.2f  %s"):format(utils.trunc(t.mod, 58), t.duration_ms, bar)
  end

  if #timings == 0 then
    lines[#lines + 1] = "  (no profiling data — set profile = true in loader.setup)"
  else
    lines[#lines + 1] = HR
    lines[#lines + 1] = ("  %-58s %8.2f"):format("TOTAL", profiler.get_total_ms())
  end

  open_float("Load Time Profile", lines)
end

-- ── :LoaderModules ────────────────────────────────────────────────────────────

local function cmd_modules()
  local reg = modules.get_all()
  local ord_idx = modules.load_order_index()

  local STATE_ICON = {
    loaded = "✓",
    failed = "✗",
    skipped = "~",
    loading = "…",
    registered = "○",
    pending = "◌",
  }

  local rows = {}
  for mod, spec in pairs(reg) do
    local s = modules.get_state(mod)
    local t = profiler.get(mod)
    rows[#rows + 1] = {
      mod = mod,
      state = s,
      icon = STATE_ICON[s] or "?",
      ms = t and ("%.2f"):format(t.duration_ms) or "-",
      ord = ord_idx[mod] and tostring(ord_idx[mod]) or "-",
      priority = spec.priority or "normal",
    }
  end

  -- Sort: loaded first (by load order), then rest alphabetically.
  table.sort(rows, function(a, b)
    local oa = ord_idx[a.mod] or math.huge
    local ob = ord_idx[b.mod] or math.huge
    if oa ~= ob then
      return oa < ob
    end
    return a.mod < b.mod
  end)

  local lines = {
    "Module Registry",
    HR,
    ("  %-2s %-50s %-12s %8s %5s  %s"):format("", "Module", "State", "ms", "#", "Priority"),
    HR,
  }
  for _, r in ipairs(rows) do
    lines[#lines + 1] = ("  %s  %-49s %-12s %8s %5s  %s"):format(
      r.icon,
      utils.trunc(r.mod, 49),
      r.state,
      r.ms,
      r.ord,
      r.priority
    )
  end

  open_float("Module Registry", lines)
end

-- ── :LoaderSlowmods ──────────────────────────────────────────────────────────

local function cmd_slowmods(opts)
  local threshold = tonumber(opts.args) or 5
  local slow = profiler.get_slow(threshold)

  local lines = {
    ("Slow Modules  (threshold: %d ms)"):format(threshold),
    HR,
    ("  %-60s %10s"):format("Module", "ms"),
    HR,
  }
  for _, r in ipairs(slow) do
    lines[#lines + 1] = ("  %-60s %8.2f"):format(utils.trunc(r.mod, 60), r.duration_ms)
  end
  if #slow == 0 then
    lines[#lines + 1] = ("  (no modules exceed %d ms)"):format(threshold)
  end

  open_float("Slow Modules", lines)
end

-- ── :LoaderReload ─────────────────────────────────────────────────────────────

local function cmd_reload(opts)
  local mod = vim.trim(opts.args or "")
  if mod == "" then
    utils.log("warn", "Usage: LoaderReload <module.name>")
    return
  end
  local core = require("custom.loader.core")
  local ok = core.reload(mod)
  vim.notify(
    ok and ("Reloaded: %s"):format(mod) or ("Reload failed: %s"):format(mod),
    ok and vim.log.levels.INFO or vim.log.levels.ERROR,
    { title = "custom.loader" }
  )
end

local function complete_mods(arglead)
  local mods = {}
  for mod in pairs(modules.get_all()) do
    if mod:find(arglead, 1, true) then
      mods[#mods + 1] = mod
    end
  end
  -- Also complete any cached module for ad-hoc reload.
  for mod in pairs(package.loaded) do
    if mod:find(arglead, 1, true) and not modules.get(mod) then
      mods[#mods + 1] = mod
    end
  end
  table.sort(mods)
  return mods
end

-- ── Setup: register all commands ─────────────────────────────────────────────

function M.setup()
  local cmds = {
    { name = "LoaderStats", fn = cmd_stats, desc = "Loader: overview stats" },
    { name = "LoaderProfile", fn = cmd_profile, desc = "Loader: load time profile" },
    { name = "LoaderModules", fn = cmd_modules, desc = "Loader: module registry" },
    { name = "LoaderSlowmods", fn = cmd_slowmods, desc = "Loader: slow module report", nargs = "?" },
    {
      name = "LoaderReload",
      fn = cmd_reload,
      desc = "Loader: force-reload a module",
      nargs = 1,
      complete = complete_mods,
    },
  }

  for _, c in ipairs(cmds) do
    vim.api.nvim_create_user_command(c.name, c.fn, {
      desc = c.desc,
      nargs = c.nargs or 0,
      complete = c.complete,
    })
  end
end

return M
