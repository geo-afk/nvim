-- explorer/tree.lua
-- Serial depth-first async tree builder.
-- Children always appear directly below their parent (guaranteed DFS order).

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'

local M = {}

local uv = vim.uv or vim.loop

-- ── Path helpers ─────────────────────────────────────────────────────────

M.norm = function(p)
  return (p:gsub('//+', '/'):gsub('/$', ''))
end
M.join = function(a, b)
  return M.norm(a .. '/' .. b)
end
M.parent = function(p)
  return p:match '^(.*)/[^/]+$' or '/'
end

-- ── Directory scanning ────────────────────────────────────────────────────
-- Uses uv.fs_scandir() (non-blocking single syscall), iterates synchronously
-- inside the callback (fast, no event-loop blocking per entry).

local function scan(path, show_hidden, cb)
  -- vim.schedule_wrap ensures the callback runs in Neovim's main loop, not in
  -- libuv's fast-event context where nvim_* API calls are forbidden.
  uv.fs_scandir(
    path,
    vim.schedule_wrap(function(err, handle)
      if err or not handle then
        cb {}
        return
      end
      local entries = {}
      while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if show_hidden or name:sub(1, 1) ~= '.' then
          local abs = M.join(path, name)
          if t == 'link' then
            local s = uv.fs_stat(abs)
            t = s and s.type or 'link'
          end
          entries[#entries + 1] = { name = name, type = t, path = abs }
        end
      end
      table.sort(entries, function(a, b)
        local ad = a.type == 'directory' and 0 or 1
        local bd = b.type == 'directory' and 0 or 1
        if ad ~= bd then
          return ad < bd
        end
        return a.name:lower() < b.name:lower()
      end)
      cb(entries)
    end)
  )
end

-- ── Filter helper ─────────────────────────────────────────────────────────
-- Returns true if any item in a flat list matches the filter.
-- Used by walk() to decide whether to include an item or its children.

local function matches(name, filter)
  if not filter or filter == '' then
    return true
  end
  -- Case-insensitive substring match (fast, good enough for file trees)
  return name:lower():find(filter:lower(), 1, true) ~= nil
end

-- ── Serial DFS walk ───────────────────────────────────────────────────────
-- Each directory waits for its scan to complete before recursing into
-- open sub-directories, ensuring correct DFS order in `result`.

local function walk(path, depth, parents_last, tok, result, filter, on_done)
  vim.schedule(function()
    if S.build_tok ~= tok then
      return
    end -- stale build, abandon

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

        -- Filtering: include this item if its name matches,
        -- or if it's a dir that might contain matches (we'll discover via recursion).
        -- For simplicity we always include dirs when filtered (prune in render if empty).
        local visible = (not filter or filter == '') or matches(e.name, filter) or e.type == 'directory'

        if visible then
          result[#result + 1] = {
            path = e.path,
            name = e.name,
            depth = depth,
            is_dir = (e.type == 'directory'),
            is_open = is_open,
            is_last = is_last,
            parents_last = parents_last,
          }
        end

        if e.type == 'directory' and is_open then
          local pl = vim.list_extend({}, parents_last)
          pl[#pl + 1] = is_last
          walk(e.path, depth + 1, pl, tok, result, filter, function()
            process(i + 1)
          end)
        else
          process(i + 1)
        end
      end

      process(1)
    end)
  end)
end

-- ── Public: build_tree ─────────────────────────────────────────────────────
-- build_tree(token, filter, done)
-- Rebuilds S.items asynchronously. If S.build_tok changes before completion,
-- the build is silently abandoned.

function M.build(tok, filter, done)
  local result = {}
  walk(S.root, 0, {}, tok, result, filter, function()
    if S.build_tok == tok then
      done(result)
    end
  end)
end

return M
