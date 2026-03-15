-- tabline/buffers.lua
-- Owns all buffer-related state:
--   • A custom-ordered list of buffer numbers (so users can reorder tabs)
--   • Utility functions: sync, move, close, deduplicated display names
--
-- DESIGN NOTES
-- ─────────────
-- • `state.order` is the single source of truth for tab order.
--   It is kept in sync lazily: any call that needs the list calls sync()
--   first, which removes deleted/unlisted buffers and appends new ones.
-- • Buffer deletion uses vim.api.nvim_buf_delete() (force=true) which is a
--   clean Lua API call with proper error propagation — unlike pcall around
--   "silent! bwipeout!" which always returns ok=true and never lets the
--   fallback branch run (FIX #5).
-- • Before deleting, every window that shows the target buffer is redirected
--   to the focus target, not just the current window (FIX #6).

local M = {}

--- Internal mutable state.
local state = {
  order = {}, ---@type integer[]  ordered list of bufnrs
}

-- ─── helpers ──────────────────────────────────────────────────────────────

local function is_listed(b)
  return vim.fn.buflisted(b) == 1
end

local function is_valid_listed(b)
  return vim.api.nvim_buf_is_valid(b) and is_listed(b)
end

-- ─── core ─────────────────────────────────────────────────────────────────

--- Synchronise state.order with the live buffer list.
---@return integer[]
function M.sync()
  local all      = vim.api.nvim_list_bufs()
  local live_set = {}
  local live_list = {}
  for _, b in ipairs(all) do
    if is_valid_listed(b) then
      live_set[b]               = true
      live_list[#live_list + 1] = b
    end
  end

  -- Keep existing order but prune dead buffers
  local new_order = {}
  local in_order  = {}
  for _, b in ipairs(state.order) do
    if live_set[b] then
      new_order[#new_order + 1] = b
      in_order[b]               = true
    end
  end

  -- Append any buffers not yet tracked (typically just-opened)
  for _, b in ipairs(live_list) do
    if not in_order[b] then
      new_order[#new_order + 1] = b
    end
  end

  state.order = new_order
  return new_order
end

--- Return the ordered list of listed buffers (syncs first).
---@return integer[]
function M.get_buffers()
  return M.sync()
end

--- Return the 1-based position of bufnr in the ordered list, or nil.
---@param bufnr integer
---@return integer|nil
function M.get_index(bufnr)
  for i, b in ipairs(state.order) do
    if b == bufnr then return i end
  end
  return nil
end

-- ─── reorder ──────────────────────────────────────────────────────────────

--- Swap bufnr one position to the left.
---@param bufnr integer
function M.move_left(bufnr)
  local bufs = M.sync()
  local idx  = M.get_index(bufnr)
  if idx and idx > 1 then
    bufs[idx], bufs[idx - 1] = bufs[idx - 1], bufs[idx]
  end
end

--- Swap bufnr one position to the right.
---@param bufnr integer
function M.move_right(bufnr)
  local bufs = M.sync()
  local idx  = M.get_index(bufnr)
  if idx and idx < #bufs then
    bufs[idx], bufs[idx + 1] = bufs[idx + 1], bufs[idx]
  end
end

-- ─── close ────────────────────────────────────────────────────────────────

--- Determine which buffer to focus after closing `bufnr`.
---@param bufnr   integer
---@param bufs    integer[]
---@param focus   string    "left"|"right"|"previous"
---@return integer|nil
local function pick_focus_target(bufnr, bufs, focus)
  local idx = M.get_index(bufnr)
  if not idx or #bufs <= 1 then return nil end

  if focus == "right" then
    if idx < #bufs then return bufs[idx + 1] end
    return bufs[idx - 1]

  elseif focus == "previous" then
    local alt = vim.fn.bufnr("#")
    if alt ~= -1 and alt ~= bufnr and is_valid_listed(alt) then
      return alt
    end
    -- fall through to "left"
  end

  -- Default / "left"
  if idx > 1 then return bufs[idx - 1] end
  return bufs[2]  -- was first; go to what becomes the new first
end

--- Safely delete a buffer via the Neovim API.
--- FIX #5: The old implementation used pcall(vim.cmd, "silent! bwipeout! N").
--- `silent!` suppresses Vimscript errors so pcall always gets ok=true —
--- meaning the "fallback" bdelete branch never ran.
--- nvim_buf_delete with force=true is the correct, error-surfacing API call.
---@param bufnr integer
local function delete_buf(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  if not ok then
    -- Surface the error as a non-fatal notification rather than swallowing it.
    vim.notify("tabline: could not delete buffer " .. bufnr .. ": " .. tostring(err),
               vim.log.levels.WARN)
  end
end

--- Close bufnr, switching away all windows that currently show it.
--- FIX #6: Previously only the *current* window was redirected. Any split
--- or floating window also showing the buffer was left pointing at a
--- deleted buffer, which causes Neovim to display "[No Name]" or error.
---@param bufnr  integer
---@param focus  string  "left"|"right"|"previous"
function M.close(bufnr, focus)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local bufs = M.sync()
  if #bufs == 0 then return end

  -- If this is the last listed buffer, open a blank buffer first
  if #bufs == 1 then
    vim.cmd("enew")
    delete_buf(bufnr)
    return
  end

  local target = pick_focus_target(bufnr, bufs, focus or "left")

  if target then
    -- FIX #6: Redirect every window that shows `bufnr`, not just the
    -- current one.  nvim_list_wins() returns all windows in all tabs.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win)
         and vim.api.nvim_win_get_buf(win) == bufnr then
        -- pcall because the window could close during iteration
        pcall(vim.api.nvim_win_set_buf, win, target)
      end
    end
  end

  delete_buf(bufnr)
end

-- ─── display names ────────────────────────────────────────────────────────

--- Return the raw display path/label for a buffer (before deduplication).
---@param b integer
---@return string raw_label, boolean is_special
local function raw_label(b)
  local bt   = vim.bo[b].buftype
  local name = vim.api.nvim_buf_get_name(b)

  if bt == "terminal" then
    local term_title = vim.b[b].term_title or ""
    if term_title ~= "" then
      return term_title:match("^%d+: (.+)$") or term_title, true
    end
    return "terminal", true

  elseif name == "" then
    return "[No Name]", true

  else
    return name, false
  end
end

--- Compute unique, short display names for a list of buffers.
--- Strategy:
--   1. Use just the tail (filename).
--   2. If two files share the same tail, prepend successive parent
--      directory components until they are unique (or run out of path).
--   3. Truncate to max_len with a trailing ellipsis if needed.
---@param bufs    integer[]
---@param max_len integer   0 = no limit
---@return table<integer, string>
function M.get_display_names(bufs, max_len)
  if #bufs == 0 then return {} end

  local raw     = {}
  local special = {}
  for _, b in ipairs(bufs) do
    raw[b], special[b] = raw_label(b)
  end

  -- Group non-special buffers by their tail (filename)
  local tail_to_bufs = {}
  for _, b in ipairs(bufs) do
    if not special[b] then
      local tail = vim.fn.fnamemodify(raw[b], ":t")
      if tail == "" then tail = raw[b] end
      tail_to_bufs[tail]                    = tail_to_bufs[tail] or {}
      tail_to_bufs[tail][#tail_to_bufs[tail] + 1] = b
    end
  end

  local names = {}

  -- Special buffers get their raw label directly
  for _, b in ipairs(bufs) do
    if special[b] then names[b] = raw[b] end
  end

  -- For each group of same-tailed buffers, extend path until unique
  for _, conflict_bufs in pairs(tail_to_bufs) do
    if #conflict_bufs == 1 then
      local b    = conflict_bufs[1]
      names[b]   = vim.fn.fnamemodify(raw[b], ":t")
    else
      -- Build a list-of-path-parts for each buffer in the conflict group
      local displays = {}
      for _, b in ipairs(conflict_bufs) do
        local parts = {}
        for seg in (raw[b] .. "/"):gmatch("([^/]+)/") do
          parts[#parts + 1] = seg
        end
        displays[b] = { parts = parts, depth = 1 }
      end

      for _ = 1, 8 do  -- max 8 path components deep
        -- Compute current display string for each buffer
        local cur = {}
        for _, b in ipairs(conflict_bufs) do
          local d     = displays[b]
          local n     = #d.parts
          local depth = math.min(d.depth, n)
          local seg   = {}
          for k = n - depth + 1, n do seg[#seg + 1] = d.parts[k] end
          cur[b] = table.concat(seg, "/")
        end

        -- Check uniqueness
        local seen       = {}
        local all_unique = true
        for _, b in ipairs(conflict_bufs) do
          if seen[cur[b]] then all_unique = false; break end
          seen[cur[b]] = true
        end

        if all_unique then
          for _, b in ipairs(conflict_bufs) do names[b] = cur[b] end
          break
        end

        -- Extend depth for still-conflicting buffers
        local still = {}
        for s, _ in pairs(seen) do
          local cnt = 0
          for _, b in ipairs(conflict_bufs) do
            if cur[b] == s then cnt = cnt + 1 end
          end
          if cnt > 1 then
            for _, b in ipairs(conflict_bufs) do
              if cur[b] == s then still[b] = true end
            end
          end
        end

        local extended = false
        for _, b in ipairs(conflict_bufs) do
          if still[b] then
            local d = displays[b]
            if d.depth < #d.parts then d.depth = d.depth + 1; extended = true end
          end
        end

        if not extended then
          -- Ran out of path components; assign whatever we have
          for _, b in ipairs(conflict_bufs) do
            if not names[b] then names[b] = cur[b] end
          end
          break
        end
      end

      -- Safety fallback
      for _, b in ipairs(conflict_bufs) do
        if not names[b] then names[b] = vim.fn.fnamemodify(raw[b], ":t") end
      end
    end
  end

  -- Final fallback: every buf must have a name
  for _, b in ipairs(bufs) do
    if not names[b] then names[b] = raw[b] end
  end

  -- Truncate long names
  if max_len and max_len > 0 then
    for _, b in ipairs(bufs) do
      local nm = names[b]
      if #nm > max_len then
        names[b] = nm:sub(1, max_len - 1) .. "…"
      end
    end
  end

  return names
end

return M
