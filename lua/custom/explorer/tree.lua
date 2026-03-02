-- custom/explorer/tree.lua
-- Serial depth-first async tree builder with live-filter support.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'

local M = {}
local uv = vim.uv or vim.loop

-- ── Path helpers ──────────────────────────────────────────────────────────

M.norm = function(p)
  return (p:gsub('//+', '/'):gsub('/$', ''))
end
M.join = function(a, b)
  return M.norm(a .. '/' .. b)
end
M.parent = function(p)
  return p:match '^(.*)/[^/]+$' or '/'
end

-- ── Directory scan ────────────────────────────────────────────────────────

local function scan(path, show_hidden, cb)
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

local function matches(name, filter)
  if not filter or filter == '' then
    return true
  end
  return name:lower():find(filter:lower(), 1, true) ~= nil
end

-- ── DFS walk ─────────────────────────────────────────────────────────────
-- Normal mode: only recurse into open dirs.
-- Filter mode: recurse into ALL dirs; only show dirs with matching descendants.

local function walk(path, depth, parents_last, tok, result, filter, on_done)
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
        local filtering = filter and filter ~= ''

        if e.type == 'directory' then
          if filtering then
            -- Collect children first; only show dir if it yields matches
            local sub = {}
            local pl = vim.list_extend({}, parents_last)
            pl[#pl + 1] = is_last
            local dir_entry = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = true,
              is_open = true,
              is_last = is_last,
              parents_last = parents_last,
            }
            walk(e.path, depth + 1, pl, tok, sub, filter, function()
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
            -- Normal: include dir, recurse only if open
            result[#result + 1] = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = true,
              is_open = is_open,
              is_last = is_last,
              parents_last = parents_last,
            }
            if is_open then
              local pl = vim.list_extend({}, parents_last)
              pl[#pl + 1] = is_last
              walk(e.path, depth + 1, pl, tok, result, filter, function()
                process(i + 1)
              end)
              return
            end
          end
        else
          -- File: show if no filter or name matches
          if not filtering or matches(e.name, filter) then
            result[#result + 1] = {
              path = e.path,
              name = e.name,
              depth = depth,
              is_dir = false,
              is_open = false,
              is_last = is_last,
              parents_last = parents_last,
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
  local result = {}
  walk(S.root, 0, {}, tok, result, filter, function()
    if S.build_tok == tok then
      done(result)
    end
  end)
end

return M
