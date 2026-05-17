-- lua/custom/loader/scheduler.lua
-- Three-tier deferred execution engine.
--
--   immediate  → vim.schedule (next event-loop tick, before render)
--   deferred   → vim.defer_fn after VimEnter + config.defer_timeout ms
--   idle       → CursorHold/CursorHoldI in batches of config.idle_batch
--
-- Design constraints:
--   • No busy-waits, no timer abuse.
--   • Idle loader self-destructs when the queue empties.
--   • Deferred flush triggers idle setup automatically.
--   • All errors are caught per-item; one failure cannot block the queue.

local M = {}
local utils = require("custom.loader.utils")

local _immediate = {}
local _deferred = {}
local _idle = {}

local _idle_augroup_name = "LoaderIdleQueue"
local _idle_active = false
local _deferred_armed = false

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function safe_call(fn, label)
  local ok, err = pcall(fn)
  if not ok then
    utils.log("error", "[scheduler/%s] %s", label or "?", tostring(err))
  end
end

local function flush_list(list, label)
  -- Snapshot + clear before iteration so callbacks can enqueue more items safely.
  local items = {}
  for i = 1, #list do
    items[i] = list[i]
    list[i] = nil
  end
  for i = 1, #items do
    if type(items[i]) == "function" then
      safe_call(items[i], label)
    end
  end
end

-- ── Idle loader ───────────────────────────────────────────────────────────────

local function idle_tick()
  if #_idle == 0 then
    -- Queue drained — tear down the autocmd.
    pcall(vim.api.nvim_del_augroup_by_name, _idle_augroup_name)
    _idle_active = false
    return
  end

  local cfg = require("custom.loader.state").config
  local batch = math.min(cfg.idle_batch, #_idle)
  for _ = 1, batch do
    local fn = table.remove(_idle, 1)
    if type(fn) == "function" then
      safe_call(fn, "idle")
    end
  end
end

function M._setup_idle_loader()
  if _idle_active or #_idle == 0 then
    return
  end
  _idle_active = true
  local aug = vim.api.nvim_create_augroup(_idle_augroup_name, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = aug,
    callback = idle_tick,
  })
end

-- ── Public scheduling API ─────────────────────────────────────────────────────

--- Run `fn` on the very next event-loop tick (non-blocking).
function M.schedule_immediate(fn)
  _immediate[#_immediate + 1] = fn
  vim.schedule(function()
    -- Only pop from front — FIFO ordering.
    local f = table.remove(_immediate, 1)
    if type(f) == "function" then
      safe_call(f, "immediate")
    end
  end)
end

--- Run `fn` after VimEnter + defer_timeout ms.
--- Call M.flush_deferred() from VimEnter to arm the timer.
function M.schedule_deferred(fn)
  _deferred[#_deferred + 1] = fn
end

--- Run `fn` during idle time (CursorHold).
function M.schedule_idle(fn)
  _idle[#_idle + 1] = fn
end

--- Arm the deferred timer. Call this once from the VimEnter callback.
--- After the timer fires, idle-loader setup is attempted automatically.
function M.flush_deferred()
  if _deferred_armed then
    return
  end
  _deferred_armed = true
  local timeout = require("custom.loader.state").config.defer_timeout
  vim.defer_fn(function()
    flush_list(_deferred, "deferred")
    M._setup_idle_loader()
    _deferred_armed = false
  end, timeout)
end

-- ── Introspection ─────────────────────────────────────────────────────────────

function M.get_queue_sizes()
  return {
    immediate = #_immediate,
    deferred = #_deferred,
    idle = #_idle,
  }
end

return M
