-- lua/custom/loader/core.lua
-- The authoritative loading engine.
--
-- Responsibilities:
--   • Condition evaluation
--   • Dependency resolution (DFS, cycle-safe)
--   • Safe require() with profiling
--   • Post-load config callbacks
--   • State-machine transitions
--   • Cache invalidation for reload
--
-- This module is the only caller of require() for user modules.
-- Everything else asks core.load() — never calls require() directly.

local M = {}

local utils = require("custom.loader.utils")
local cache = require("custom.loader.cache")
local profiler = require("custom.loader.profiler")
local modules = require("custom.loader.modules")
local deps_mod = require("custom.loader.dependencies")

-- ── Internal: single module require ──────────────────────────────────────────

local function do_require(mod)
  modules.set_state(mod, modules.S.LOADING)
  profiler.start(mod)

  local ok, result = utils.safe_require(mod)

  profiler.stop(mod)

  if not ok then
    modules.set_state(mod, modules.S.FAILED)
    local t = profiler.get(mod)
    utils.log("error", "load failed: %s (%.2f ms)", mod, t and t.duration_ms or 0)
    return false, result
  end

  cache.mark_loaded(mod)
  modules.set_state(mod, modules.S.LOADED)

  local t = profiler.get(mod)
  utils.log("debug", "loaded: %s (%.2f ms)", mod, t and t.duration_ms or 0)

  return true, result
end

-- ── Internal: run post-load callback ─────────────────────────────────────────

local function run_config(spec, result)
  local cb = spec and (spec.config or spec.on_load)
  if type(cb) ~= "function" then
    return true
  end
  local ok, err = pcall(cb, result)
  if not ok then
    utils.log("error", "config callback for %s: %s", spec.mod, tostring(err))
    modules.set_state(spec.mod, modules.S.FAILED)
    return false
  end
  return true
end

-- ── Internal: dependency resolution ──────────────────────────────────────────
-- Ensures all direct dependencies of `root_mod` are loaded.
-- Cycle detection is handled by the caller (M.load) using the `visited` stack.

local function load_deps(root_mod, visited)
  local queue = deps_mod.get_direct(root_mod)
  for _, dep in ipairs(queue) do
    if not modules.is_loaded(dep) then
      local ok = M.load(dep, { trigger = "dependency", _visited = visited })
      if not ok then
        return false, dep
      end
    end
  end
  return true
end

local function eval_cond(spec)
  if not spec or spec.cond == nil then
    return true
  end

  if type(spec.cond) ~= "function" then
    return spec.cond == true
  end

  local ok, result = pcall(spec.cond)
  if not ok then
    return false, result
  end

  return result == true
end

-- ── Public: load a single module ─────────────────────────────────────────────

--- Load module `mod`, respecting condition, dependencies, and state.
---
---@param mod   string
---@param opts? { trigger?: string, force?: boolean, _visited?: table }
---@return boolean ok
function M.load(mod, opts)
  opts = opts or {}

  -- Guard: already loaded (skip unless forced).
  if modules.is_loaded(mod) and not opts.force then
    return true
  end

  if modules.is_loading(mod) and not opts.force then
    utils.log("debug", "already loading: %s", mod)
    return true
  end

  -- Guard: previously failed (don't retry unless forced).
  if modules.is_failed(mod) and not opts.force then
    utils.log("debug", "skipping previously failed: %s", mod)
    return false
  end

  -- Circular dependency detection (DFS stack-based).
  local visited = opts._visited or {}
  if visited[mod] then
    utils.log("warn", "circular dependency detected: %s", mod)
    return false
  end

  -- Guard: module not yet registered → load it directly (ad-hoc require).
  local spec = modules.get(mod)

  -- Evaluate condition.
  local cond_ok, cond_err = eval_cond(spec)
  if not cond_ok then
    modules.set_state(mod, modules.S.SKIPPED)
    if cond_err ~= nil then
      utils.log("warn", "condition failed for %s: %s", mod, tostring(cond_err))
    else
      utils.log("debug", "condition false, skipped: %s", mod)
    end
    return false
  end

  -- Resolve and load dependencies before loading the module itself.
  visited[mod] = true
  local deps_ok, failed_dep = load_deps(mod, visited)
  visited[mod] = nil -- Backtrack for cycle detection
  if not deps_ok then
    modules.set_state(mod, modules.S.FAILED)
    utils.log("error", "dependency failed for %s: %s", mod, tostring(failed_dep))
    return false
  end

  -- Perform the actual require.
  local ok, result = do_require(mod)
  if not ok then
    return false
  end

  -- Post-load config callback.
  if not run_config(spec, result) then
    return false
  end

  return true
end

-- ── Public: batch load in dependency order ────────────────────────────────────

---@param mod_list string[]
---@param opts?    { trigger?: string, force?: boolean, continue_on_error?: boolean }
function M.load_batch(mod_list, opts)
  opts = opts or {}
  local sorted, cycles = deps_mod.topo_sort(mod_list)

  if #cycles > 0 then
    utils.log("error", "circular deps detected, refusing batch load: %s", table.concat(cycles, ", "))
    return false
  end

  local all_ok = true
  for _, mod in ipairs(sorted) do
    if not M.load(mod, opts) then
      all_ok = false
      if not opts.continue_on_error then
        return false
      end
    end
  end
  return all_ok
end

-- ── Public: force reload ──────────────────────────────────────────────────────

---@param mod string
---@return boolean ok
function M.reload(mod)
  cache.invalidate(mod)
  -- Reset state so load() doesn't short-circuit.
  if modules.get_state(mod) ~= "unregistered" then
    modules.set_state(mod, modules.S.REGISTERED)
  end
  utils.log("info", "reloading: %s", mod)
  return M.load(mod, { force = true, trigger = "reload" })
end

return M
