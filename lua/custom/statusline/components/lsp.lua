-- =============================================================================
-- statusline/components/lsp.lua
-- =============================================================================
--
-- SPINNER DESIGN
-- ──────────────
-- A uv.new_timer() fires every 150 ms while LSP progress tokens are active.
-- The callback calls M.redraw_fn() — which IS init.lua's schedule_redraw() —
-- so every tick passes through the 16 ms time-gate and cannot race a scroll.
--
-- Key ordering rule (this was the crash bug):
--   active_tokens MUST be declared before start_spinner() is defined,
--   because the timer closure captures it as an upvalue. If start_spinner
--   is defined first, the closure captures the global `active_tokens`
--   (nil), and `next(nil)` crashes on every timer tick.
--
-- TOKEN TRACKING
-- ──────────────
-- active_tokens[client_id][token] = begin_timestamp_ms
-- Spinner runs iff count_tokens() > 0.
-- Watchdog evicts tokens older than WATCHDOG_MS (handles crashed servers).
-- =============================================================================

local M = {}
local hl = require('custom.statusline.highlights').hl
local utils = require 'custom.statusline.utils'
local diag = vim.diagnostic
local uv = vim.uv or vim.loop

-- Injected by init.lua — the debounced, time-gated schedule_redraw().
-- Default no-op until wired up.
M.redraw_fn = function() end

-- ── Constants ────────────────────────────────────────────────────────────────
local SPINNER_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local SPINNER_INTERVAL = 150 -- ms between frames (~6 fps)
local WATCHDOG_MS = 30000 -- evict tokens open longer than this

-- ── Spinner state ─────────────────────────────────────────────────────────────
local spinner_idx = 1
local spinner_timer = nil -- uv timer handle; nil when idle

-- ── Token registry ────────────────────────────────────────────────────────────
-- MUST be declared before start_spinner() / stop_spinner() so the timer
-- closure captures the local table, not a nil global.
local active_tokens = {} -- [client_id] = { [token] = begin_ms }

-- ── Token helpers ─────────────────────────────────────────────────────────────
local function count_tokens()
  local n = 0
  for _, t in pairs(active_tokens) do
    for _ in pairs(t) do
      n = n + 1
    end
  end
  return n
end

local function sweep_stale(now)
  for cid, tokens in pairs(active_tokens) do
    for tok, ts in pairs(tokens) do
      if (now - ts) > WATCHDOG_MS then
        tokens[tok] = nil
      end
    end
    if not next(tokens) then
      active_tokens[cid] = nil
    end
  end
end

-- ── Spinner lifecycle ─────────────────────────────────────────────────────────
-- Defined AFTER active_tokens so the closure captures the local correctly.

local function start_spinner()
  if spinner_timer then
    return
  end -- already running; no-op
  spinner_timer = uv.new_timer()
  spinner_timer:start(
    0,
    SPINNER_INTERVAL,
    vim.schedule_wrap(function()
      -- active_tokens is captured correctly here because it was declared above.
      if count_tokens() == 0 then
        -- All tokens cleared between ticks — self-stop.
        if spinner_timer then
          spinner_timer:stop()
          spinner_timer:close()
          spinner_timer = nil
        end
        spinner_idx = 1
        M.redraw_fn() -- one final redraw to show the idle indicator
        return
      end
      spinner_idx = (spinner_idx % #SPINNER_FRAMES) + 1
      M.redraw_fn() -- debounced; safe against scroll races
    end)
  )
end

local function stop_spinner()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  spinner_idx = 1
end

-- =============================================================================
-- Public API
-- =============================================================================

--- Called from the LspProgress autocmd in init.lua with the raw event table.
function M.on_progress(ev)
  local client_id = ev.data and ev.data.client_id
  local params = ev.data and ev.data.params
  if not client_id or not params then
    return
  end

  local token = params.token
  local value = params.value
  local kind = value and value.kind or 'report'

  if kind == 'begin' then
    active_tokens[client_id] = active_tokens[client_id] or {}
    active_tokens[client_id][token] = uv.now()
    start_spinner() -- no-op if already running
  elseif kind == 'end' then
    if active_tokens[client_id] then
      active_tokens[client_id][token] = nil
      if not next(active_tokens[client_id]) then
        active_tokens[client_id] = nil
      end
    end
    -- If that was the last token, stop spinner and do one final redraw.
    if count_tokens() == 0 then
      stop_spinner()
      M.redraw_fn()
    end
  end
  -- "report" events carry percentage — no state change needed.
end

--- Force-clear all tokens for a client (called on LspDetach).
function M.clear_client(client_id)
  active_tokens[client_id] = nil
  if count_tokens() == 0 then
    stop_spinner()
  end
end

-- ── Diagnostic cache ──────────────────────────────────────────────────────────
-- Invalidated by DiagnosticChanged autocmd in init.lua.

local diag_cache = {} -- [bufnr] = { e, w, h, i }

local function get_diags(bufnr)
  if diag_cache[bufnr] then
    return diag_cache[bufnr]
  end
  local counts = diag.count(bufnr)
  local r = {
    e = counts[diag.severity.ERROR] or 0,
    w = counts[diag.severity.WARN] or 0,
    h = counts[diag.severity.HINT] or 0,
    i = counts[diag.severity.INFO] or 0,
  }
  diag_cache[bufnr] = r
  return r
end

function M.invalidate_diags(bufnr)
  diag_cache[bufnr] = nil
end

-- ── Client name cache ─────────────────────────────────────────────────────────
-- Invalidated by LspAttach / LspDetach in init.lua.

local client_cache = {} -- [bufnr] = string

local function get_client_str(bufnr)
  if client_cache[bufnr] then
    return client_cache[bufnr]
  end
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  if #clients == 0 then
    client_cache[bufnr] = ''
    return ''
  end
  local seen, names = {}, {}
  for _, c in ipairs(clients) do
    if not seen[c.name] then
      seen[c.name] = true
      if c.name ~= 'null-ls' and c.name ~= 'none-ls' then
        names[#names + 1] = c.name
      elseif #clients == 1 then
        names[#names + 1] = c.name
      end
    end
  end
  local r = table.concat(names, ', ')
  client_cache[bufnr] = r
  return r
end

function M.invalidate_clients(bufnr)
  client_cache[bufnr] = nil
end

-- ── Render ────────────────────────────────────────────────────────────────────

function M.render(winid, bufnr)
  local win_width = vim.api.nvim_win_get_width(winid)
  local compact = win_width < 80

  -- Periodic watchdog: sweep stale tokens on every render (very cheap path).
  sweep_stale(uv.now())

  local parts = {}
  local is_loading = count_tokens() > 0

  -- Diagnostics (cached per buffer)
  local d = get_diags(bufnr)
  if d.e > 0 then
    parts[#parts + 1] = hl 'StatusLineDiagError' .. '󰅚 ' .. d.e .. hl 'StatusLine'
  end
  if d.w > 0 then
    parts[#parts + 1] = hl 'StatusLineDiagWarn' .. '󰀪 ' .. d.w .. hl 'StatusLine'
  end
  if not compact then
    if d.h > 0 then
      parts[#parts + 1] = hl 'StatusLineDiagHint' .. '󰌶 ' .. d.h .. hl 'StatusLine'
    end
    if d.i > 0 then
      parts[#parts + 1] = hl 'StatusLineDiagInfo' .. ' ' .. d.i .. hl 'StatusLine'
    end
  end

  -- Spinner (loading) or idle indicator
  if is_loading then
    -- Also advance frame here so keypress activity adds bonus smoothness
    -- on top of the timer's base animation.
    spinner_idx = (spinner_idx % #SPINNER_FRAMES) + 1
    parts[#parts + 1] = hl 'StatusLineLSPLoad' .. ' ' .. SPINNER_FRAMES[spinner_idx] .. ' ' .. hl 'StatusLine'
  else
    -- Static idle dot when an LSP is attached but not loading.
    -- get_clients() is cheap and only called in this non-loading branch.
    local clients = vim.lsp.get_clients { bufnr = bufnr }
    if #clients > 0 then
      parts[#parts + 1] = hl 'StatusLineLSPActive' .. ' 󰄴 ' .. hl 'StatusLine'
    end
  end

  -- Client names (full width only, cached)
  if not compact then
    local names = get_client_str(bufnr)
    if names ~= '' then
      parts[#parts + 1] = hl 'StatusLineLSPName' .. names .. hl 'StatusLine'
    end
  end

  if #parts == 0 then
    return ''
  end
  return utils.join(parts, ' ')
end

return M
