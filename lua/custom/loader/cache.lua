-- lua/custom/loader/cache.lua
-- Thin wrapper around package.loaded.
-- Tracks which modules our loader owns and detects duplicate requires.
-- No eviction policy — Neovim's process lifetime is the scope.

local M = {}

-- How many times each module has been required through our loader.
-- (package.loaded already de-dupes, so count > 1 means explicit re-loading.)
local _counts = {}

-- Modules whose cache entry was set by this loader (vs required externally).
local _owned = {}

-- ── Core operations ───────────────────────────────────────────────────────────

function M.get(mod)
  return package.loaded[mod]
end

--- Record that we just loaded `mod` (does not mutate package.loaded itself).
function M.mark_loaded(mod)
  _counts[mod] = (_counts[mod] or 0) + 1
  _owned[mod] = true
end

--- Evict a module so the next require() re-executes it.
function M.invalidate(mod)
  package.loaded[mod] = nil
  _owned[mod] = nil
  -- Keep the count so the profiler can show "reloaded N times".
end

function M.is_loaded(mod)
  return package.loaded[mod] ~= nil
end

function M.is_owned(mod)
  return _owned[mod] == true
end

function M.get_count(mod)
  return _counts[mod] or 0
end

-- ── Analysis helpers ──────────────────────────────────────────────────────────

--- Return modules that were loaded more than once (sorted by count desc).
function M.get_duplicates()
  local result = {}
  for mod, count in pairs(_counts) do
    if count > 1 then
      result[#result + 1] = { mod = mod, count = count }
    end
  end
  table.sort(result, function(a, b)
    return a.count > b.count
  end)
  return result
end

--- Return every module currently in package.loaded, annotated with ownership.
function M.snapshot()
  local result = {}
  for mod in pairs(package.loaded) do
    result[#result + 1] = {
      mod = mod,
      owned = _owned[mod] == true,
      count = _counts[mod] or 0,
    }
  end
  table.sort(result, function(a, b)
    return a.mod < b.mod
  end)
  return result
end

return M
