-- =============================================================================
-- statusline/components/lsp.lua  (no-timer edition)
-- =============================================================================
--
-- PERFORMANCE + CURSOR FLASH FIX: TIMER REMOVED
-- ───────────────────────────────────────────────
-- The 120 ms repeating timer was the primary source of the cursor-jump artifact
-- during scrolling (neovim/neovim#20582). Even at 120 ms it fired ~8× per
-- second, giving plenty of opportunities to race Neovim's natural scroll-draw
-- pass and send a wrong cursor-goto command to the terminal.
--
-- NEW SPINNER DESIGN — frame-advance in render()
-- ────────────────────────────────────────────────
-- spinner_idx is incremented directly inside render() on every eval() call.
-- Since eval() fires on every keypress (scroll, typing, cursor move), the
-- spinner animates naturally during user activity — exactly when it's visible.
--
-- "But what if the user is idle waiting for LSP?"
-- A single vim.defer_fn wakeup fires 300 ms after the first "begin" event.
-- This one redraw makes the spinner appear even if no key has been pressed,
-- without creating a repeating timer race condition.
--
-- TOKEN TRACKING (from previous revision — unchanged)
-- ────────────────────────────────────────────────────
-- active_tokens[client_id][token] = timestamp_ms
-- Spinner runs iff count_tokens() > 0.
-- Watchdog in render() evicts stale tokens (> 30 s) to survive crashed servers.
-- =============================================================================

local M = {}
local hl = require('custom.statusline.highlights').hl
local diag = vim.diagnostic
local uv = vim.uv or vim.loop

M.redraw_fn = function() end

-- ---------------------------------------------------------------------------
-- Spinner  (NO timer — frame advances in render())
-- ---------------------------------------------------------------------------
local SPINNER_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local WATCHDOG_MS = 30000 -- evict tokens older than this (crashed servers)

local spinner_idx = 1
local _wakeup_pending = false -- prevents multiple deferred wakeups

-- ---------------------------------------------------------------------------
-- Token registry  [client_id] = { [token] = begin_timestamp_ms }
-- ---------------------------------------------------------------------------
local active_tokens = {}

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
  local evicted = 0
  for cid, tokens in pairs(active_tokens) do
    for tok, ts in pairs(tokens) do
      if (now - ts) > WATCHDOG_MS then
        tokens[tok] = nil
        evicted = evicted + 1
      end
    end
    if not next(tokens) then
      active_tokens[cid] = nil
    end
  end
  return evicted
end

-- ---------------------------------------------------------------------------
-- Single deferred wakeup when LSP loading starts and user may be idle.
-- ---------------------------------------------------------------------------
local function maybe_wakeup()
  if _wakeup_pending then
    return
  end
  _wakeup_pending = true
  -- Fire once, 300 ms after the begin event, so the spinner is visible even
  -- if the user hasn't pressed a key yet.
  vim.defer_fn(function()
    _wakeup_pending = false
    if count_tokens() > 0 then
      M.redraw_fn()
    end
  end, 300)
end

-- ---------------------------------------------------------------------------
-- Public: progress event handler
-- ---------------------------------------------------------------------------
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
    maybe_wakeup()
  elseif kind == 'end' then
    if active_tokens[client_id] then
      active_tokens[client_id][token] = nil
      if not next(active_tokens[client_id]) then
        active_tokens[client_id] = nil
      end
    end
    -- If all tokens cleared, fire one final redraw to show idle state.
    if count_tokens() == 0 then
      M.redraw_fn()
    end
  end
end

function M.clear_client(client_id)
  active_tokens[client_id] = nil
end

-- ---------------------------------------------------------------------------
-- Diagnostic cache  (invalidated by DiagnosticChanged autocmd in init.lua)
-- ---------------------------------------------------------------------------
local diag_cache = {}

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

-- ---------------------------------------------------------------------------
-- Client name cache  (invalidated by LspAttach/LspDetach in init.lua)
-- ---------------------------------------------------------------------------
local client_cache = {}

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
  local r = table.concat(names, ',')
  client_cache[bufnr] = r
  return r
end

function M.invalidate_clients(bufnr)
  client_cache[bufnr] = nil
end

-- ---------------------------------------------------------------------------
-- Render  — the only place spinner_idx advances (no timer needed)
-- ---------------------------------------------------------------------------
function M.render(winid, bufnr)
  local win_width = vim.api.nvim_win_get_width(winid)
  local compact = win_width < 80
  local now = uv.now()

  -- Periodic stale-token sweep (cheap: runs every render, exits fast if clean)
  sweep_stale(now)

  local parts = {}
  local is_loading = count_tokens() > 0

  -- Diagnostics (cached)
  local d = get_diags(bufnr)
  if d.e > 0 then
    parts[#parts + 1] = hl 'StatusLineDiagError' .. ' ' .. d.e .. hl 'StatusLine'
  end
  if d.w > 0 then
    parts[#parts + 1] = hl 'StatusLineDiagWarn' .. ' ' .. d.w .. hl 'StatusLine'
  end
  if not compact then
    if d.h > 0 then
      parts[#parts + 1] = hl 'StatusLineDiagHint' .. '󰌵' .. d.h .. hl 'StatusLine'
    end
    if d.i > 0 then
      parts[#parts + 1] = hl 'StatusLineDiagInfo' .. ' ' .. d.i .. hl 'StatusLine'
    end
  end
  -- Spinner / idle indicator
  if is_loading then
    -- Advance frame on every render call — animates during user input,
    -- pauses during true idle (which is fine — user isn't watching then).
    spinner_idx = (spinner_idx % #SPINNER_FRAMES) + 1
    parts[#parts + 1] = hl 'StatusLineLSPLoad' .. SPINNER_FRAMES[spinner_idx] .. hl 'StatusLine'
  else
    -- Show a static idle dot if any LSP client is attached.
    -- get_clients is cheap here because we only call it when NOT loading.
    local clients = vim.lsp.get_clients { bufnr = bufnr }
    if #clients > 0 then
      parts[#parts + 1] = hl 'StatusLineLSPActive' .. '󰄴' .. hl 'StatusLine'
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
  return ' ' .. table.concat(parts, ' ') .. ' '
end

return M
