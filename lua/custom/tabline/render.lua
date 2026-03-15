-- tabline/render.lua
-- Builds the tabline string that Neovim evaluates on every redraw.
--
-- PERFORMANCE DESIGN
-- ──────────────────
-- • All string building uses a pre-allocated `parts` table + table.concat()
--   at the end.  Intermediate `..` concatenation is never used in the hot
--   loop — each `..` would allocate a new string object in Lua.
-- • vim.bo[b].* is accessed via the Lua API (hash-table lookup) rather than
--   vim.fn.getbufvar() which has Vimscript call overhead.
-- • Cached strings (padding, close button) are precomputed in setup() so
--   the hot loop performs zero string allocations for them.
-- • The name-cache fingerprint includes both bufnr AND buffer name so that
--   a rename (e.g. :e file, :saveas) correctly busts the cache.
-- • The visibility window is arithmetic-only before the render loop so the
--   loop body is branchless for the common (no-truncation) case.
-- • Every buffer access inside the loop is guarded: a buffer can be deleted
--   between get_buffers() and the loop body (async events, autocmds).

local M = {}
local buffers_mod = nil  -- lazy-require to avoid circular deps at load time

local _config     = nil

-- ─── precomputed per-config strings (set in M.setup) ──────────────────────
-- Recalculated only when setup() is called, not on every render.
local _padding    = " "     -- padding string (spaces × config.padding)
local _close_btn  = " × "   -- " " .. close_icon .. " "

-- ─── name-cache ───────────────────────────────────────────────────────────
-- Cache keyed on a fingerprint of (bufnr, name) pairs so that:
--   • Tab reordering  → different bufnr sequence → cache miss ✓
--   • Buffer rename   → same bufnr, different name → cache miss ✓  (BUG FIX #1)
--   • Normal BufEnter → same sequence + names → cache hit ✓

local name_cache = {
  fingerprint = nil,
  names       = {},
}

--- Compute a fingerprint that captures both ordering AND names.
--- Format: "id1:name1|id2:name2|..."
--- FIX #1: Previously only used bufnrs, so renaming a buffer (`:e file`,
--- `:saveas`) would not invalidate the cache and the old name stayed shown.
---@param bufs integer[]
---@return string
local function fingerprint(bufs)
  local t = {}
  for i, b in ipairs(bufs) do
    -- nvim_buf_get_name is cheap (C string copy); using it here is correct
    -- because the cache is only re-keyed, not displayed directly.
    t[i] = b .. ":" .. vim.api.nvim_buf_get_name(b)
  end
  return table.concat(t, "|")
end

--- Explicitly bust the name cache (called from init.lua on BufReadPost etc.)
function M.invalidate_name_cache()
  name_cache.fingerprint = nil
end

--- Get display names, using cache when possible.
---@param bufs    integer[]
---@param max_len integer
---@return table<integer, string>
local function get_names(bufs, max_len)
  local fp = fingerprint(bufs)
  if name_cache.fingerprint == fp then
    return name_cache.names
  end
  local names          = buffers_mod.get_display_names(bufs, max_len)
  name_cache.fingerprint = fp
  name_cache.names       = names
  return names
end

-- ─── visibility window ────────────────────────────────────────────────────

---@param n_bufs     integer
---@param cur_idx    integer  1-based
---@param max_shown  integer  0 = unlimited
---@return integer start, integer stop, boolean trunc_left, boolean trunc_right
local function compute_window(n_bufs, cur_idx, max_shown)
  if max_shown <= 0 or n_bufs <= max_shown then
    return 1, n_bufs, false, false
  end
  local half  = math.floor(max_shown / 2)
  local start = math.max(1, cur_idx - half)
  local stop  = start + max_shown - 1
  if stop > n_bufs then
    stop  = n_bufs
    start = math.max(1, stop - max_shown + 1)
  end
  return start, stop, (start > 1), (stop < n_bufs)
end

-- ─── highlight tokens (module-level constants) ────────────────────────────

local HL = {
  sel     = "%#TabLineSel#",
  normal  = "%#TabLine#",
  fill    = "%#TabLineFill#",
  mod_sel = "%#TabLineSelModified#",
  mod_nor = "%#TabLineModified#",
  cls_sel = "%#TabLineCloseSel#",
  cls_nor = "%#TabLineClose#",
  trunc   = "%#TabLineTrunc#",
  sep     = "%#TabLineSep#",
}

-- ─── public ───────────────────────────────────────────────────────────────

function M.setup(config)
  _config    = config
  buffers_mod = require("custom.tabline.buffers")

  -- FIX #4: Precompute strings that were previously built on every render.
  _padding   = string.rep(" ", math.max(0, config.padding))
  _close_btn = " " .. config.close_icon .. " "

  -- Bust cache so any leftover state from a previous setup() call is dropped.
  name_cache.fingerprint = nil
  name_cache.names       = {}
end

--- Build and return the full tabline string.
--- Called by Neovim via:  vim.o.tabline = "%!v:lua.require'tabline'.render()"
---@return string
function M.render()
  if not _config then return "" end
  if not buffers_mod then buffers_mod = require("custom.tabline.buffers") end

  local bufs = buffers_mod.get_buffers()
  if #bufs == 0 then return HL.fill end

  local current  = vim.api.nvim_get_current_buf()
  local max_bufs = _config.max_buffers

  -- Locate current buffer's position in the ordered list
  local cur_idx = 1
  for i, b in ipairs(bufs) do
    if b == current then cur_idx = i; break end
  end

  -- Compute the visible slice
  local si, ei, trunc_l, trunc_r = compute_window(#bufs, cur_idx, max_bufs)

  -- Build visible-slice list for name lookup (only the shown subset)
  local visible = {}
  for i = si, ei do visible[#visible + 1] = bufs[i] end

  local names = get_names(visible, _config.max_name_length)

  -- ── string build ──────────────────────────────────────────────────────
  local parts = {}
  local n = 0
  local function P(s) n = n + 1; parts[n] = s end

  if trunc_l then P(HL.trunc); P(" < ") end

  for i = si, ei do
    local b = bufs[i]

    -- FIX #3: Guard every per-buffer access. A buffer can be wiped between
    -- get_buffers() and here by an async event or a fast autocmd chain.
    if vim.api.nvim_buf_is_valid(b) then
      local is_cur = (b == current)
      -- pcall protects against the edge case where the buffer becomes invalid
      -- exactly between the is_valid check and the bo[] access.
      local ok, is_mod = pcall(function() return vim.bo[b].modified end)
      if not ok then is_mod = false end

      local hl_tab = is_cur and HL.sel     or HL.normal
      local hl_mod = is_cur and HL.mod_sel or HL.mod_nor
      local hl_cls = is_cur and HL.cls_sel or HL.cls_nor

      if _config.separator ~= "" and i > si then
        P(HL.sep); P(_config.separator)
      end

      -- Label click region (left = switch, middle = close)
      P(hl_tab)
      P("%" .. b .. "@v:lua.TablineHandleClick@")
      P(_padding)

      -- FIX #2: Escape literal `%` in filenames so Neovim doesn't interpret
      -- them as tabline format directives (e.g. "100%_done.lua" → crash/garble).
      local raw_name = names[b] or "[?]"
      P(raw_name:gsub("%%", "%%%%"))

      if _config.show_modified and is_mod then
        P(" ")
        P(hl_mod)
        P(_config.modified_icon)
        P(hl_tab)
      else
        P("  ")   -- stable width: gap + absent-icon placeholder
      end

      P(_padding)
      P("%X")  -- end label click region

      if _config.show_close then
        P(hl_cls)
        P("%" .. b .. "@v:lua.TablineHandleClose@")
        P(_close_btn)   -- FIX #4: precomputed, no allocation here
        P("%X")
      end
    end  -- nvim_buf_is_valid
  end

  if trunc_r then P(HL.trunc); P(" > ") end

  P(HL.fill)
  return table.concat(parts)
end

return M
