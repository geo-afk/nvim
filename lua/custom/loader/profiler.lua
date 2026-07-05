-- lua/custom/loader/profiler.lua
-- High-resolution (nanosecond) per-module load-time profiler.
-- Uses vim.uv.hrtime() — monotonic, no wall-clock drift.
-- All data is accumulated in-process; zero disk I/O.

local M = {}
local utils = require("custom.loader.utils")

-- Deferred access to state to avoid import cycle at module init time
-- (mirrors utils.lua's own cfg() pattern).
local function cfg()
  return require("custom.loader.state").config
end

-- Wall-clock reference: nanoseconds at the moment this file was first required.
-- This approximates "Neovim startup origin" when loaded early.
local _origin_ns = utils.hrtime()

-- Per-module timing records: mod -> { start_ns, stop_ns, duration_ms }
local _records = {}

-- Active (open) timers: mod -> start_ns
local _active = {}

-- ── Timer control ─────────────────────────────────────────────────────────────
-- Gated on config.profile: disabled (the default) means zero overhead here.

function M.start(mod)
  if not cfg().profile then
    return
  end
  _active[mod] = utils.hrtime()
end

function M.stop(mod)
  if not cfg().profile then
    return
  end
  local t0 = _active[mod]
  if not t0 then
    return
  end
  local t1 = utils.hrtime()
  _records[mod] = {
    start_ns = t0,
    stop_ns = t1,
    duration_ms = utils.ns_to_ms(t1 - t0),
  }
  _active[mod] = nil
end

-- Record a duration that was measured externally (e.g. from a benchmark shim).
function M.record(mod, duration_ms)
  _records[mod] = { duration_ms = duration_ms }
end

-- ── Accessors ─────────────────────────────────────────────────────────────────

function M.get(mod)
  return _records[mod]
end

--- All records sorted by duration descending.
function M.get_all()
  local result = {}
  for mod, r in pairs(_records) do
    result[#result + 1] = { mod = mod, duration_ms = r.duration_ms }
  end
  table.sort(result, function(a, b)
    return a.duration_ms > b.duration_ms
  end)
  return result
end

--- Modules slower than `threshold_ms` (default 5 ms).
function M.get_slow(threshold_ms)
  threshold_ms = threshold_ms or 5
  local result = {}
  for _, r in ipairs(M.get_all()) do
    if r.duration_ms >= threshold_ms then
      result[#result + 1] = r
    end
  end
  return result
end

--- Sum of all tracked load durations.
function M.get_total_ms()
  local total = 0
  for _, r in pairs(_records) do
    total = total + r.duration_ms
  end
  return total
end

--- Milliseconds since this profiler module was first loaded (startup proxy).
function M.elapsed_ms()
  return utils.ns_to_ms(utils.hrtime() - _origin_ns)
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

function M.reset()
  _records = {}
  _active = {}
end

return M
