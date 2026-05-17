-- lua/custom/loader/core.lua
-- The authoritative loading engine.
--
-- Responsibilities:
--   • Condition evaluation
--   • Dependency resolution (iterative, cycle-safe)
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
    return
  end
  local ok, err = pcall(cb, result)
  if not ok then
    utils.log("error", "config callback for %s: %s", spec.mod, tostring(err))
  end
end

-- ── Internal: dependency resolution ──────────────────────────────────────────
-- Iterative BFS to load all unloaded dependencies before the target module.
-- Guards against circular dependencies via a per-call visited set.

local function load_deps(root_mod, visited)
  visited = visited or {}
  local queue = deps_mod.get_direct(root_mod)
  local seen = {}

  local i = 1
  while i <= #queue do
    local dep = queue[i]
    i = i + 1
    if not seen[dep] then
      seen[dep] = true
      if visited[dep] then
        utils.log("warn", "circular dependency: %s ← %s", dep, root_mod)
      elseif not modules.is_loaded(dep) then
        visited[dep] = true
        -- Load transitive deps first.
        load_deps(dep, visited)
        M.load(dep, { trigger = "dependency", _visited = visited })
        -- Enqueue dep's own deps for BFS continuation.
        for _, d2 in ipairs(deps_mod.get_direct(dep)) do
          if not seen[d2] then
            queue[#queue + 1] = d2
          end
        end
      end
    end
  end
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

  -- Guard: previously failed (don't retry unless forced).
  if modules.is_failed(mod) and not opts.force then
    utils.log("debug", "skipping previously failed: %s", mod)
    return false
  end

  -- Guard: module not yet registered → load it directly (ad-hoc require).
  local spec = modules.get(mod)

  -- Evaluate condition.
  if spec and spec.cond ~= nil then
    local cond = spec.cond
    local result = type(cond) == "function" and cond() or cond
    if not result then
      modules.set_state(mod, modules.S.SKIPPED)
      utils.log("debug", "condition false, skipped: %s", mod)
      return false
    end
  end

  -- Resolve and load dependencies.
  local visited = opts._visited or {}
  visited[mod] = true
  load_deps(mod, visited)

  -- Perform the actual require.
  local ok, result = do_require(mod)
  if not ok then
    return false
  end

  -- Post-load config callback.
  run_config(spec, result)

  return true
end

-- ── Public: batch load in dependency order ────────────────────────────────────

---@param mod_list string[]
---@param opts?    { trigger?: string, force?: boolean }
function M.load_batch(mod_list, opts)
  opts = opts or {}
  local sorted, cycles = deps_mod.topo_sort(mod_list)

  if #cycles > 0 then
    utils.log("warn", "circular deps detected, loading anyway: %s", table.concat(cycles, ", "))
    for _, m in ipairs(cycles) do
      sorted[#sorted + 1] = m
    end
  end

  for _, mod in ipairs(sorted) do
    M.load(mod, opts)
  end
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
