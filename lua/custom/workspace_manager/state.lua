--------------------------------------------------------------------------------
-- custom/workspace_manager/state.lua
-- Shared registry: an MRU stack of stashed items.
--
-- Each item:
--   id        integer            unique, monotonic
--   provider  string             provider name that captured/owns this item
--   label     string             display label (picker, notifications)
--   meta      table              provider-specific data needed to restore
--   stashed_at integer           os.time() at stash time
--------------------------------------------------------------------------------
local M = {}

M.stack = {} -- ordered, most-recently-stashed last; restore() pops the tail
M.next_id = 1

-- Guards the lazy, once-only registration of cleanup autocmds (actions.lua).
M.autocmds_ready = false

--- Push a new item onto the stack, assigning it an id.
--- @param item table  { provider, label, meta }
--- @return table item  (with id + stashed_at filled in)
function M.push(item)
  item.id = M.next_id
  item.stashed_at = os.time()
  M.next_id = M.next_id + 1
  table.insert(M.stack, item)
  return item
end

--- Remove and return an item. With no id, pops the most recent (LIFO/MRU).
--- @param id integer|nil
function M.pop(id)
  if #M.stack == 0 then
    return nil
  end
  if id == nil then
    return table.remove(M.stack)
  end
  for i = #M.stack, 1, -1 do
    if M.stack[i].id == id then
      return table.remove(M.stack, i)
    end
  end
  return nil
end

--- Look up an item without removing it.
function M.get(id)
  for _, item in ipairs(M.stack) do
    if item.id == id then
      return item
    end
  end
end

--- Find the (first, there should only ever be one) stashed item for a
--- provider marked `singleton = true` (e.g. the terminal panel, DAP UI).
function M.find_by_provider(provider_name)
  for _, item in ipairs(M.stack) do
    if item.provider == provider_name then
      return item
    end
  end
end

function M.peek()
  return M.stack[#M.stack]
end

function M.count()
  return #M.stack
end

--- Snapshot for the picker / :WorkspaceList, most-recent first.
function M.list()
  local out = {}
  for i = #M.stack, 1, -1 do
    out[#out + 1] = M.stack[i]
  end
  return out
end

return M
