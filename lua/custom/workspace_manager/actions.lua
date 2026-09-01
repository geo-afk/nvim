--------------------------------------------------------------------------------
-- custom/workspace_manager/actions.lua
-- stash / restore / toggle / terminate / remove / rename.
--------------------------------------------------------------------------------
local M = {}

-- ── Source-window detection ───────────────────────────────────────────────────
-- A "source" window is ordinary project/file editing: not stashed by default
-- (see providers.lua's generic catch-all — it would otherwise happily grab
-- main.ts). Pass { force = true } to stash one anyway.
local function is_source_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and vim.fn.buflisted(buf) == 1
end

-- ── Focus history ──────────────────────────────────────────────────────────────
-- Computed on demand at stash time from the CURRENT window layout — not a
-- background-tracked history. There is nothing to get stale and nothing
-- running when nothing is stashed.
local function find_fallback_window(exclude)
  local ok, altwin = pcall(function()
    return vim.fn.win_getid(vim.fn.winnr("#"))
  end)
  if ok and altwin ~= 0 and altwin ~= exclude and is_source_window(altwin) then
    return altwin
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= exclude and is_source_window(win) then
      return win
    end
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if win ~= exclude and is_source_window(win) then
        return win
      end
    end
  end
  return nil
end

-- ── Stale-buffer cleanup ───────────────────────────────────────────────────────
-- Registered lazily, once, the first time anything is stashed. Per-buffer and
-- `once = true`: no scanning, nothing left running once each fires.
local augroup_id

--- Which buffer (if any) backs this item and could be deleted out from under
--- it while hidden. Panel/layout providers (managed_terminal, dap,
--- overseer_panel) own their own multi-window lifecycle and are not tracked
--- here — see providers.lua.
local function buf_to_watch(item)
  if item.provider == "generic" then
    return item.meta.buf
  elseif item.provider == "float_term" then
    local ok, floating = pcall(require, "custom.float_term.floating")
    if ok then
      local f = floating.get(item.meta.float_id)
      return f and f.buf
    end
  end
  return nil
end

local function ensure_cleanup_autocmd(item)
  local buf = buf_to_watch(item)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local state = require("custom.workspace_manager.state")
  if not state.autocmds_ready then
    augroup_id = vim.api.nvim_create_augroup("WorkspaceManagerCleanup", { clear = true })
    state.autocmds_ready = true
  end
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = augroup_id,
    buffer = buf,
    once = true,
    callback = function()
      if state.pop(item.id) then
        vim.notify('Workspace: "' .. item.label .. '" was deleted while stashed', vim.log.levels.WARN)
      end
    end,
  })
end

-- ── Public actions ─────────────────────────────────────────────────────────────

--- @param opts? { win?: integer, force?: boolean, notify?: boolean, label?: string }
--- @return integer|nil id
function M.stash(opts)
  opts = opts or {}
  local win = opts.win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  if is_source_window(win) and not opts.force then
    if opts.notify ~= false then
      vim.notify("Workspace: nothing to stash here (it's a regular file window)", vim.log.levels.INFO)
    end
    return nil
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local providers = require("custom.workspace_manager.providers")
  local state = require("custom.workspace_manager.state")
  local provider = providers.match(win, buf)
  if not provider then
    return nil
  end

  if provider.singleton and state.find_by_provider(provider.name) then
    if opts.notify ~= false then
      vim.notify("Workspace: already stashed", vim.log.levels.INFO)
    end
    return nil
  end

  local meta = provider.capture(win, buf)
  local label = opts.label or provider.label(meta)
  local fallback = find_fallback_window(win)

  if not provider.hide(win, meta) then
    if opts.notify ~= false then
      vim.notify('Workspace: could not stash "' .. label .. '"', vim.log.levels.WARN)
    end
    return nil
  end

  local item = state.push({ provider = provider.name, label = label, meta = meta })
  ensure_cleanup_autocmd(item)

  if fallback and vim.api.nvim_win_is_valid(fallback) then
    pcall(vim.api.nvim_set_current_win, fallback)
  end

  if opts.notify ~= false then
    vim.notify("Stashed: " .. label, vim.log.levels.INFO)
  end
  return item.id
end

--- @param opts? { id?: integer, notify?: boolean }
--- @return boolean
function M.restore(opts)
  opts = opts or {}
  local state = require("custom.workspace_manager.state")
  local item = opts.id and state.get(opts.id) or state.peek()
  if not item then
    if opts.notify ~= false then
      vim.notify("Workspace: nothing to restore", vim.log.levels.INFO)
    end
    return false
  end

  local providers = require("custom.workspace_manager.providers")
  local provider = providers.get(item.provider)
  local result = provider and provider.restore(item.meta)
  if not result then
    vim.notify(
      'Workspace: could not restore "' .. item.label .. '" (its window/buffer/task no longer exists)',
      vim.log.levels.WARN
    )
    state.pop(item.id)
    return false
  end

  state.pop(item.id)
  if type(result) == "number" then
    pcall(vim.api.nvim_set_current_win, result)
  end
  if opts.notify ~= false then
    vim.notify("Restored: " .. item.label, vim.log.levels.INFO)
  end
  return true
end

--- Minimize/restore in one key: stash the current window if it's a
--- stashable auxiliary UI, otherwise restore the most recently stashed item.
function M.toggle()
  local win = vim.api.nvim_get_current_win()
  if not is_source_window(win) then
    local id = M.stash({ win = win, notify = false })
    if id then
      local state = require("custom.workspace_manager.state")
      vim.notify("Stashed: " .. state.get(id).label, vim.log.levels.INFO)
      return true
    end
  end
  return M.restore()
end

--- Drop an item from the registry without restoring it.
function M.remove(id)
  local state = require("custom.workspace_manager.state")
  local item = state.pop(id)
  if item then
    vim.notify('Workspace: removed "' .. item.label .. '" (left as-is, not restored)', vim.log.levels.INFO)
    return true
  end
  return false
end

--- Explicitly terminate the underlying process/session, then drop it.
--- Distinct from remove(): remove() leaves the terminal/session running
--- hidden; terminate() ends it.
function M.terminate(id)
  local state = require("custom.workspace_manager.state")
  local item = id and state.get(id) or state.peek()
  if not item then
    return false
  end
  -- Remove from the registry BEFORE deleting anything: provider.terminate()
  -- may synchronously delete a buffer, which fires the BufWipeout/BufDelete
  -- cleanup autocmd (see ensure_cleanup_autocmd) inline. Popping first makes
  -- that autocmd a no-op instead of emitting a spurious "deleted while
  -- stashed" warning for a deletion we ourselves just asked for.
  state.pop(item.id)
  local providers = require("custom.workspace_manager.providers")
  local provider = providers.get(item.provider)
  if provider and provider.terminate then
    provider.terminate(item.meta)
  end
  vim.notify('Workspace: terminated "' .. item.label .. '"', vim.log.levels.WARN)
  return true
end

function M.rename(id, name)
  local state = require("custom.workspace_manager.state")
  local item = id and state.get(id) or state.peek()
  if not item or not name or name == "" then
    return false
  end
  item.label = name
  return true
end

function M.clear()
  local state = require("custom.workspace_manager.state")
  local n = state.count()
  for _ = 1, n do
    state.pop()
  end
  return n
end

M._is_source_window = is_source_window -- exposed for tests only

return M
