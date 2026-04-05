--- lsp-keymapper/init.lua
--- Entry point.  Call `require("lsp-keymapper").setup(opts)` in your config.
---
--- Default opts:
--- {
---   --- Automatically re-apply saved bindings every time an LSP attaches.
---   auto_apply   = true,
---
---   --- Persist bindings to disk so they survive restarts.
---   persist      = true,
---
---   --- Open the browser automatically when an LSP first attaches to a buffer
---   --- (only fires when no saved bindings exist for that client yet).
---   auto_open_on_first_attach = false,
---
---   --- Global key to open the browser manually (set to false to disable).
---   open_keymap  = "<leader>lk",
---
---   --- Filter function: receives (cap_key, def) and returns true to include.
---   --- Useful to hide capabilities you never want to map.
---   --- Example: filter = function(k, _) return k ~= "documentHighlightProvider" end
---   filter       = nil,
--- }

local M = {}
local nvim_utils = require('utils.nvim')

-- ──────────────────────────────────────────────────────────────────────────────
-- Derive the base module path from the current file so that all sibling
-- requires work regardless of where the plugin is installed.
--
--   e.g. if the user loads it as "custom.lsp_keymapper"
--        then _BASE = "custom.lsp_keymapper"
--        and siblings are required as "custom.lsp_keymapper.capabilities" etc.
-- ──────────────────────────────────────────────────────────────────────────────

--- @type string  e.g. "lsp-keymapper" or "custom.lsp_keymapper"
local _BASE = (...) -- `...` is the full dotted module name of this file

-- ──────────────────────────────────────────────────────────────────────────────
-- Lazy-load sub-modules (avoids loading them at startup)
-- ──────────────────────────────────────────────────────────────────────────────

local function caps_mod()
  return require(_BASE .. '.capabilities')
end
local function km_mod()
  return require(_BASE .. '.keymap')
end
local function ui_mod()
  return require(_BASE .. '.ui')
end
local function store_mod()
  return require(_BASE .. '.store')
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Default configuration
-- ──────────────────────────────────────────────────────────────────────────────

local DEFAULT_OPTS = {
  auto_apply = true,
  persist = true,
  auto_open_on_first_attach = false,
  open_keymap = '<leader>lk',
  filter = nil,
}

-- Resolved options (populated by setup())
local _opts = nil

-- ──────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ──────────────────────────────────────────────────────────────────────────────

--- Apply the user's custom filter to the capabilities registry.
--- Mutates caps.registry in-place for the duration of the session.
local function apply_filter(filter_fn)
  if type(filter_fn) ~= 'function' then
    return
  end
  local registry = caps_mod().registry
  for key, def in pairs(registry) do
    if not filter_fn(key, def) then
      registry[key] = nil
    end
  end
end

--- Re-apply all saved bindings for `client` onto `bufnr`.
local function reapply_saved(client, bufnr)
  if not _opts.persist then
    return
  end
  local saved = store_mod().load(client.name)
  local registry = caps_mod().registry
  km_mod().apply_bulk(bufnr, saved, registry)
end

--- Handler called on every LspAttach event.
local function on_lsp_attach(ev)
  local bufnr = ev.buf
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  if not client then
    return
  end

  -- Always re-apply persisted bindings first
  if _opts.auto_apply then
    reapply_saved(client, bufnr)
  end

  -- Optionally open the browser on first attach (no saved bindings yet)
  if _opts.auto_open_on_first_attach then
    local saved = _opts.persist and store_mod().load(client.name) or {}
    if #saved == 0 then
      vim.schedule(function()
        ui_mod().open(client, bufnr, _opts)
      end)
    end
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

--- Set up the plugin.  Must be called before any LSP servers attach.
---
--- @param user_opts table|nil  Partial options table merged with defaults.
function M.setup(user_opts)
  _opts = vim.tbl_deep_extend('force', DEFAULT_OPTS, user_opts or {})

  -- Attach the store module onto opts so ui.lua can call _opts._store.save(…)
  _opts._store = store_mod()

  -- Apply any user filter to the registry
  apply_filter(_opts.filter)

  -- Wire LspAttach autocmd
  nvim_utils.autocmd('LspAttach', {
    group = 'LspKeymapper',
    callback = on_lsp_attach,
    desc = 'lsp-keymapper: re-apply saved keymaps and optionally open browser',
  })

  -- Global key to open the browser for the current buffer's first active client
  if _opts.open_keymap then
    nvim_utils.map('n', _opts.open_keymap, function()
      M.open()
    end, {
      desc = 'LSP Keymapper: open capability browser',
      silent = true,
    })
  end

  -- User commands
  nvim_utils.command('LspKeymapBrowse', function()
    M.open()
  end, { desc = 'Open the LSP capability browser for the current buffer' })

  nvim_utils.command('LspKeymapReset', function(cmd_opts)
    local name = cmd_opts.args ~= '' and cmd_opts.args or nil
    M.reset(name)
  end, {
    nargs = '?',
    desc = 'Clear saved LSP keymaps. Pass client name to target one client.',
    complete = function()
      local all = store_mod().load_all()
      return vim.tbl_keys(all)
    end,
  })

  nvim_utils.command('LspKeymapShow', function()
    M.show_saved()
  end, { desc = 'Print all saved LSP keymaps' })
end

--- Open the capability browser for the active LSP client on the current buffer.
--- If multiple clients are attached, a picker is shown to choose one.
function M.open()
  if not _opts then
    vim.notify('[lsp-keymapper] Call setup() first.', vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = bufnr }

  if #clients == 0 then
    vim.notify('[lsp-keymapper] No LSP clients attached to this buffer.', vim.log.levels.WARN)
    return
  end

  if #clients == 1 then
    ui_mod().open(clients[1], bufnr, _opts)
    return
  end

  -- Multiple clients: let the user pick
  local names = vim.tbl_map(function(c)
    return c.name
  end, clients)
  vim.ui.select(names, {
    prompt = 'Select LSP client:',
  }, function(choice)
    if not choice then
      return
    end
    for _, c in ipairs(clients) do
      if c.name == choice then
        ui_mod().open(c, bufnr, _opts)
        return
      end
    end
  end)
end

--- Print all saved bindings in a human-readable format.
function M.show_saved()
  local all = store_mod().load_all()
  if vim.tbl_isempty(all) then
    vim.notify('[lsp-keymapper] No saved bindings found.', vim.log.levels.INFO)
    return
  end

  local registry = caps_mod().registry
  local lines = { '── Saved LSP Keymapper Bindings ──' }

  for client_name, entries in pairs(all) do
    table.insert(lines, string.format('\n  Client: %s', client_name))
    for _, e in ipairs(entries) do
      local label = registry[e.cap_key] and registry[e.cap_key].label or e.cap_key
      table.insert(lines, string.format('    %-30s  →  %s', label, e.lhs))
    end
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

--- Clear persisted bindings.
---
--- @param client_name  string|nil  If given, clear only that client; otherwise clear all.
function M.reset(client_name)
  local store = store_mod()
  if client_name then
    store.clear(client_name)
    vim.notify(string.format("[lsp-keymapper] Cleared bindings for '%s'.", client_name), vim.log.levels.INFO)
  else
    local all = store.load_all()
    for name in pairs(all) do
      store.clear(name)
    end
    vim.notify('[lsp-keymapper] Cleared all saved bindings.', vim.log.levels.INFO)
  end
end

--- Expose sub-modules for power-users who want to extend the plugin.
M.capabilities = caps_mod
M.keymap = km_mod
M.store = store_mod

return M
