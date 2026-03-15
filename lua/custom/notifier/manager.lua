-- plugin/notify-manager.lua
-- User commands for all features.

if vim.g.loaded_notify_manager then
  return
end
vim.g.loaded_notify_manager = true

local function nm()
  return require 'custom.notifier'
end

-- ── Core ──────────────────────────────────────────────────────────

vim.api.nvim_create_user_command('NotifyHistory', function(args)
  -- Optional args: "level=WARN", "source=lua_ls", "sort=level"
  local opts = {}
  for _, part in ipairs(vim.split(args.args, '%s+')) do
    local k, v = part:match '^(%w+)=(.+)$'
    if k and v then
      opts[k] = v
    end
  end
  nm().show_history(opts)
end, { nargs = '*', desc = 'Show notification history' })

vim.api.nvim_create_user_command('NotifyDismissAll', function()
  nm().dismiss_all()
end, { desc = 'Dismiss all active notifications' })

vim.api.nvim_create_user_command('NotifyClearHistory', function()
  nm().clear_history()
  vim.notify('[notifier] History cleared.', vim.log.levels.INFO)
end, { desc = 'Clear notification history' })

-- ── Feature #7: Snooze / Pause ────────────────────────────────────

vim.api.nvim_create_user_command('NotifyPause', function()
  nm().pause()
  vim.notify('[notifier] Notifications paused.', vim.log.levels.INFO)
end, { desc = 'Pause (snooze) all notifications' })

vim.api.nvim_create_user_command('NotifyResume', function()
  local count = nm().queued_count()
  nm().resume()
  vim.notify(string.format('[notifier] Resumed. Flushed %d queued notification(s).', count), vim.log.levels.INFO)
end, { desc = 'Resume notifications and flush queue' })

vim.api.nvim_create_user_command('NotifyTogglePause', function()
  nm().toggle_pause()
  local state = nm().is_paused() and 'paused' or 'active'
  vim.notify('[notifier] Notifications ' .. state .. '.', vim.log.levels.INFO)
end, { desc = 'Toggle pause state' })

-- ── Feature #4: Telescope ─────────────────────────────────────────

vim.api.nvim_create_user_command('NotifyTelescope', function()
  nm().telescope()
end, { desc = 'Open notification history in Telescope' })

-- ── Test helper ───────────────────────────────────────────────────

vim.api.nvim_create_user_command('NotifyTest', function(args)
  local n = tonumber(args.args) or 1
  local msgs = {
    { 'Build succeeded in 0.42 s', vim.log.levels.INFO, 'Cargo' },
    { "Unused variable 'x' on line 42", vim.log.levels.WARN, 'ESLint' },
    { 'Cannot read property of undefined', vim.log.levels.ERROR, 'JS' },
    { 'Reloading config…', vim.log.levels.DEBUG, 'nvim' },
    { 'File saved', vim.log.levels.INFO, nil },
  }
  for i = 1, n do
    local m = msgs[((i - 1) % #msgs) + 1]
    vim.defer_fn(function()
      nm().notify(m[1], m[2], { title = m[3] })
    end, (i - 1) * 300)
  end
end, { nargs = '?', desc = 'Trigger N test notifications' })

-- ── Feature #1: quick route-add command ───────────────────────────
-- :NotifyIgnore lua_ls        → add lua_ls to ignore list at runtime
-- :NotifyIgnore find=pattern  → skip messages matching pattern

vim.api.nvim_create_user_command('NotifyIgnore', function(args)
  local a = args.args
  if a == '' then
    vim.notify('[notifier] Usage: :NotifyIgnore <source>  or  :NotifyIgnore find=<pattern>', vim.log.levels.INFO)
    return
  end
  local _nm = nm()
  local cfg = _nm._cfg -- direct access for runtime mutation
  if not cfg then
    vim.notify('[notifier] Not yet set up.', vim.log.levels.WARN)
    return
  end
  local k, v = a:match '^(%w+)=(.+)$'
  if k == 'find' then
    table.insert(cfg.routes, 1, { filter = { find = v }, opts = { skip = true } })
    vim.notify('[notifier] Skipping messages matching: ' .. v, vim.log.levels.INFO)
  else
    -- treat as source name
    table.insert(cfg.ignore, a)
    vim.notify('[notifier] Ignoring source: ' .. a, vim.log.levels.INFO)
  end
end, { nargs = '?', desc = 'Ignore a source or pattern at runtime' })

-- ── Suggested keymaps (uncomment to enable) ───────────────────────

local k = '<cmd>Notify'
vim.keymap.set('n', '<leader>nh', k .. 'History<cr>', { desc = 'Notification history' })
vim.keymap.set('n', '<leader>nt', k .. 'Telescope<cr>', { desc = 'Notification history (Telescope)' })
vim.keymap.set('n', '<leader>nd', k .. 'DismissAll<cr>', { desc = 'Dismiss all' })
vim.keymap.set('n', '<leader>np', k .. 'TogglePause<cr>', { desc = 'Toggle notifications pause' })
vim.keymap.set('n', '<leader>nc', k .. 'ClearHistory<cr>', { desc = 'Clear history' })
