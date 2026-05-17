-- lua/custom/loader/dependencies.lua
-- Directed acyclic graph (DAG) for module dependencies.
-- Topological sort uses Kahn's algorithm (O(V+E), no recursion).
-- Cycle detection is exact: any node not emitted by Kahn is in a cycle.

local M = {}
local utils = require("custom.loader.utils")

-- Adjacency list: mod -> list of direct dependencies.
local _deps = {}

-- ── Registration ──────────────────────────────────────────────────────────────

--- Record that `mod` depends on each module in the `deps` list.
function M.register(mod, deps)
  if not _deps[mod] then
    _deps[mod] = {}
  end
  for _, dep in ipairs(deps) do
    if not utils.list_contains(_deps[mod], dep) then
      _deps[mod][#_deps[mod] + 1] = dep
    end
  end
end

-- ── Queries ───────────────────────────────────────────────────────────────────

--- Direct dependencies of `mod`.
function M.get_direct(mod)
  return _deps[mod] or {}
end

--- All transitive dependencies of `mod` via depth-first search.
--- Returns a flat list (may contain duplicates only if there are multiple paths;
--- dedup is the caller's responsibility if needed).
function M.get_transitive(mod, _visited)
  _visited = _visited or {}
  if _visited[mod] then
    return {}
  end
  _visited[mod] = true
  local result = {}
  for _, dep in ipairs(_deps[mod] or {}) do
    result[#result + 1] = dep
    for _, transitive in ipairs(M.get_transitive(dep, _visited)) do
      result[#result + 1] = transitive
    end
  end
  return result
end

-- ── Topological sort ──────────────────────────────────────────────────────────

--- Sort `mod_list` so every module appears after all its dependencies.
--- Returns: sorted (table), cycles (table of cycle participants).
---
--- Only edges between nodes present in `mod_list` are considered;
--- external deps that are not in the list are silently ignored for
--- ordering purposes (they are assumed to load on-demand via require).
function M.topo_sort(mod_list)
  -- Build a set for quick membership check.
  local in_set = {}
  for _, m in ipairs(mod_list) do
    in_set[m] = true
  end

  -- in_degree[m]  = number of deps-of-m that are also in mod_list.
  -- rev_adj[dep]  = list of mods that depend on dep (reverse edges).
  local in_degree = {}
  local rev_adj = {}

  for _, m in ipairs(mod_list) do
    in_degree[m] = in_degree[m] or 0
    for _, dep in ipairs(_deps[m] or {}) do
      if in_set[dep] then
        rev_adj[dep] = rev_adj[dep] or {}
        rev_adj[dep][#rev_adj[dep] + 1] = m
        in_degree[m] = in_degree[m] + 1
      end
    end
  end

  -- Seed the queue with nodes that have no in-set dependencies.
  local queue = {}
  for _, m in ipairs(mod_list) do
    if in_degree[m] == 0 then
      queue[#queue + 1] = m
    end
  end

  local sorted = {}
  while #queue > 0 do
    local m = table.remove(queue, 1)
    sorted[#sorted + 1] = m
    for _, dependent in ipairs(rev_adj[m] or {}) do
      in_degree[dependent] = in_degree[dependent] - 1
      if in_degree[dependent] == 0 then
        queue[#queue + 1] = dependent
      end
    end
  end

  -- Any node not emitted participates in a cycle.
  local sorted_set = {}
  for _, m in ipairs(sorted) do
    sorted_set[m] = true
  end
  local cycles = {}
  for _, m in ipairs(mod_list) do
    if not sorted_set[m] then
      cycles[#cycles + 1] = m
    end
  end

  return sorted, cycles
end

-- ── Inspection ────────────────────────────────────────────────────────────────

function M.get_graph()
  return _deps
end

return M
