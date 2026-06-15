-- custom/explorer/tree.lua
-- Serial depth-first async tree builder with live-filter support.
--
-- Fixes applied vs original:
--
--  1. parents_last mutation bug — the shared table was mutated before recursing
--     and never restored, causing incorrect connector glyphs (│ vs blank) on any
--     directory that follows another directory at the same depth.
--     Fix: snapshot and restore parents_last[depth+1] around every recursive call.
--
--  2. Synchronous symlink resolution — uv.fs_stat(abs) was called without a
--     callback, blocking the main thread for every symlink encountered during a
--     scan.  Fix: async stat via uv.fs_stat(abs, cb); symlink entries are
--     resolved concurrently with a per-directory barrier before sort+callback.
--
--  3. Filter-mode concurrency cap — in filter mode walk() recurses into ALL
--     directories simultaneously, potentially opening thousands of uv.fs_scandir
--     handles at once in large repos.  Fix: a semaphore (_inflight / MAX_INFLIGHT)
--     gates new scandir calls; excess requests are retried after a short delay.
--
--  4. Pre-computed prefix strings — instead of storing parents_last as a table on
--     every item (forcing an unpack + loop in render.lua per render), the prefix
--     string is computed once during the walk and stored directly on the item.
--     render.lua reads item._prefix and skips the per-render assembly entirely.
--     (render.lua must be updated to use item._prefix — see render.lua fix.)

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local str_utils = require("utils.strings")

local M = {}
local uv = vim.uv

-- ── Path helpers ──────────────────────────────────────────────────────────

M.norm = function(p)
  p = p:gsub("\\", "/") -- normalise backslashes (Windows / WSL paths)
  p = p:gsub("//+", "/") -- collapse consecutive forward-slashes
  if p == "/" then
    return p
  end -- preserve filesystem root
  return (p:gsub("/$", "")) -- strip trailing slash
end
M.join = function(a, b)
  return M.norm(a .. "/" .. b)
end
M.parent = function(p)
  return p:match("^(.*)/[^/]+$") or "/"
end

-- ── Concurrency gate ──────────────────────────────────────────────────────
--
-- Prevents opening too many simultaneous uv.fs_scandir handles, which in
-- filter mode on a large repo would queue thousands of schedule_wrap callbacks
-- and stall the event loop.  Excess requests are retried after 4 ms.

local _inflight = 0
local MAX_INFLIGHT = 16

-- ── Async directory scan ──────────────────────────────────────────────────
--
-- All symlinks are resolved asynchronously (uv.fs_stat with callback) before
-- the entry list is sorted and handed to the callback.  A pending counter
-- (`unresolved`) tracks in-flight stat calls; the sort+callback fires only
-- when all have returned.

local function scan(path, show_hidden, cb)
  local cache_key = path .. ":" .. tostring(show_hidden)
  local cached = S.scan_cache and S.scan_cache[cache_key]
  if cached then
    S.hidden_count = S.hidden_count + (cached.hidden_count or 0)
    cb(cached.entries or {})
    return
  end

  -- Gate: defer when too many handles are open
  if _inflight >= MAX_INFLIGHT then
    vim.defer_fn(function()
      scan(path, show_hidden, cb)
    end, 4)
    return
  end

  _inflight = _inflight + 1
  uv.fs_scandir(
    path,
    vim.schedule_wrap(function(err, handle)
      _inflight = _inflight - 1

      if err or not handle then
        local empty = {}
        if S.scan_cache then
          S.scan_cache[cache_key] = { entries = empty, hidden_count = 0 }
        end
        cb(empty)
        return
      end

      -- Collect raw entries first (synchronous iteration over the open handle is fine)
      local raw = {}
      local hidden_count = 0
      while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if show_hidden or name:sub(1, 1) ~= "." then
          raw[#raw + 1] = { name = name, type = t, path = M.join(path, name), is_link = (t == "link") }
        else
          -- Count entries skipped because show_hidden is false
          hidden_count = hidden_count + 1
        end
      end
      S.hidden_count = S.hidden_count + hidden_count

      -- Count how many symlinks need async resolution
      local unresolved = 0
      for _, e in ipairs(raw) do
        if e.is_link then
          unresolved = unresolved + 1
        end
      end

      local function maybe_done()
        if unresolved ~= 0 then
          return
        end
        -- Sort: directories first, then by name (case-insensitive)
        local entries = {}
        for _, e in ipairs(raw) do
          entries[#entries + 1] = e
        end
        table.sort(entries, function(a, b)
          local ad = a.type == "directory" and 0 or 1
          local bd = b.type == "directory" and 0 or 1
          if ad ~= bd then
            return ad < bd
          end
          return a.name:lower() < b.name:lower()
        end)
        if S.scan_cache then
          S.scan_cache[cache_key] = { entries = entries, hidden_count = hidden_count }
        end
        cb(entries)
      end

      if unresolved == 0 then
        maybe_done()
        return
      end

      -- Async symlink resolution: uv.fs_stat follows the link to get the target type
      for _, e in ipairs(raw) do
        if e.is_link then
          uv.fs_stat(
            e.path,
            vim.schedule_wrap(function(stat_err, stat)
              e.type = (stat and stat.type) or "link"
              unresolved = unresolved - 1
              maybe_done()
            end)
          )
        end
      end
    end)
  )
end

-- ── Filter helper ─────────────────────────────────────────────────────────

local function matches(name, filter)
  if not filter or filter == "" then
    return true
  end
  return str_utils.fuzzy_match(name, filter) ~= nil
end

-- ── Prefix string builder ─────────────────────────────────────────────────
--
-- Computes the tree-connector prefix string for a node directly during the
-- walk rather than storing a parents_last table and rebuilding it in render.
-- This eliminates a per-item table allocation and the per-render unpack loop.
--
-- `parents_last` is the SHARED mutable table passed through the walk.
-- It is read here (up to `depth` entries) and the resulting string is stored
-- on the item as `item._prefix`.  The `is_last` entry at index `depth+1` is
-- written BEFORE calling this function (as part of the descent bookkeeping).

local function build_prefix(parents_last, depth, is_last, tc)
  local parts = {}
  -- Ancestor connectors (depth entries from the shared table)
  for d = 1, depth do
    parts[d] = parents_last[d] and tc.blank or tc.vert
  end
  -- This node's own connector
  parts[depth + 1] = is_last and tc.last or tc.branch
  return table.concat(parts)
end

-- ── DFS walk ─────────────────────────────────────────────────────────────
-- Normal mode: only recurse into open dirs.
-- Filter mode: recurse into ALL dirs; only show dirs with matching descendants.
--
-- parents_last — shared mutable table used to build connector prefixes.
--                Each entry is true (is_last) or false for that depth.
--                MUST be snapshot+restored around every recursive call to
--                avoid corrupting sibling branch prefixes.

local function walk(path, depth, parents_last, tok, result, filter, tc, on_done)
  vim.schedule(function()
    if S.build_tok ~= tok then
      return
    end

    scan(path, cfg.get().show_hidden, function(entries)
      if S.build_tok ~= tok then
        return
      end

      local n = #entries
      local function process(i)
        if S.build_tok ~= tok then
          return
        end
        if i > n then
          on_done()
          return
        end

        local e = entries[i]
        local is_last = (i == n)
        local is_open = S.open_dirs[e.path] == true
        local filtering = filter and filter ~= ""

        if e.type == "directory" then
          -- ── Snapshot before mutation ───────────────────────────────────
          -- Write the current node's is_last at depth+1 so child nodes can
          -- read the full parents_last chain when computing their prefixes.
          local snapshot = parents_last[depth + 1]
          parents_last[depth + 1] = is_last

          local prefix = build_prefix(parents_last, depth, is_last, tc)

          if filtering then
            -- Collect children first; only include the dir if descendants match
            local sub = {}
            local dir_entry = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = true,
              is_open = true,
              is_last = is_last,
              is_link = e.is_link,
              _prefix = prefix,
            }
            walk(e.path, depth + 1, parents_last, tok, sub, filter, tc, function()
              -- ── Restore after async return ─────────────────────────────
              parents_last[depth + 1] = snapshot
              if S.build_tok ~= tok then
                return
              end
              if #sub > 0 or matches(e.name, filter) then
                result[#result + 1] = dir_entry
                for _, child in ipairs(sub) do
                  result[#result + 1] = child
                end
              end
              process(i + 1)
            end)
            return
          else
            -- Normal mode: always show dir; recurse only if open
            result[#result + 1] = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = true,
              is_open = is_open,
              is_last = is_last,
              is_link = e.is_link,
              _prefix = prefix,
            }
            if is_open then
              walk(e.path, depth + 1, parents_last, tok, result, filter, tc, function()
                -- ── Restore after async return ─────────────────────────
                parents_last[depth + 1] = snapshot
                process(i + 1)
              end)
              return
            end
            -- Not open: restore immediately before processing next sibling
            parents_last[depth + 1] = snapshot
          end
        else
          -- File: show if no filter or name matches
          if not filtering or matches(e.name, filter) then
            -- Files are leaves; build_prefix uses the current parents_last state
            -- (the parent directory has already written its is_last at depth).
            local prefix = build_prefix(parents_last, depth, is_last, tc)
            result[#result + 1] = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = false,
              is_open = false,
              is_last = is_last,
              is_link = e.is_link,
              _prefix = prefix,
            }
          end
        end

        process(i + 1)
      end

      process(1)
    end)
  end)
end

-- ── Public ────────────────────────────────────────────────────────────────

function M.build(tok, filter, done)
  -- Resolve tree connector style once per build so the walk closure has it.
  local tc = cfg.get().tree

  -- Reset the hidden-entry counter.  scan() increments it whenever a dotfile
  -- is skipped because show_hidden is false.
  S.hidden_count = 0

  local result = {}
  walk(S.root, 0, {}, tok, result, filter, tc, function()
    if S.build_tok == tok then
      done(result)
    end
  end)
end

return M
