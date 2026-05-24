-- tabline/buffers.lua
-- Owns all buffer-related state:
--   • A custom-ordered list of buffer numbers
--   • Version-based O(1) buffer list caching
--   • Utility functions: sync, move, close, deduplicated display names

local M = {}

--- Internal mutable state.
local state = {
  order = {},          ---@type integer[]  ordered list of bufnrs
  cached_bufs = nil,   ---@type integer[]|nil cached listed buffer sequence
  version = 1,         ---@type integer incremented on list changes
  cached_version = 0,  ---@type integer synced version
}

-- ─── helpers ──────────────────────────────────────────────────────────────

local function normalize_path(path)
  return (path or ""):gsub("\\", "/")
end

local function truncate_display(str, max_len)
  if not max_len or max_len <= 0 then
    return str
  end
  local chars = vim.fn.strchars(str)
  if chars <= max_len then
    return str
  end
  return vim.fn.strcharpart(str, 0, max_len - 1) .. "…"
end

local function is_listed(b)
  return vim.api.nvim_get_option_value("buflisted", { buf = b })
end

local function is_valid_listed(b)
  return vim.api.nvim_buf_is_valid(b) and is_listed(b)
end

-- ─── core ─────────────────────────────────────────────────────────────────

--- Invalidate the internal sync cache, forcing a scan on the next lookup.
function M.invalidate_cache()
  state.version = state.version + 1
end

--- Synchronise state.order with the live buffer list.
--- Uses a version counter to ensure this is an O(1) return during hot redraw frames.
---@return integer[]
function M.sync()
  if state.cached_bufs and state.version == state.cached_version then
    return state.cached_bufs
  end

  local all = vim.api.nvim_list_bufs()
  local live_set = {}
  local live_list = {}
  for _, b in ipairs(all) do
    if is_valid_listed(b) then
      live_set[b] = true
      live_list[#live_list + 1] = b
    end
  end

  -- Keep existing order but prune dead buffers
  local new_order = {}
  local in_order = {}
  for _, b in ipairs(state.order) do
    if live_set[b] then
      new_order[#new_order + 1] = b
      in_order[b] = true
    end
  end

  -- Append any buffers not yet tracked (typically just-opened)
  for _, b in ipairs(live_list) do
    if not in_order[b] then
      new_order[#new_order + 1] = b
    end
  end

  state.order = new_order
  state.cached_bufs = new_order
  state.cached_version = state.version

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
  -- Ensure state is synced
  local bufs = M.sync()
  for i, b in ipairs(bufs) do
    if b == bufnr then
      return i
    end
  end
  return nil
end

-- ─── reorder ──────────────────────────────────────────────────────────────

--- Rebuild the custom buffer order from a list of file paths.
--- Any listed buffers not present in `paths` are appended.
---@param paths string[]
---@return integer[]
function M.restore_order(paths)
  local live = M.sync()
  if type(paths) ~= "table" or #paths == 0 then
    return live
  end

  local by_name = {}
  for _, bufnr in ipairs(live) do
    local name = normalize_path(vim.api.nvim_buf_get_name(bufnr))
    if name ~= "" then
      by_name[name] = by_name[name] or {}
      by_name[name][#by_name[name] + 1] = bufnr
    end
  end

  local reordered = {}
  local seen = {}

  for _, path in ipairs(paths) do
    local key = normalize_path(path)
    for _, bufnr in ipairs(by_name[key] or {}) do
      if not seen[bufnr] and is_valid_listed(bufnr) then
        seen[bufnr] = true
        reordered[#reordered + 1] = bufnr
      end
    end
  end

  for _, bufnr in ipairs(live) do
    if not seen[bufnr] and is_valid_listed(bufnr) then
      reordered[#reordered + 1] = bufnr
    end
  end

  state.order = reordered
  state.cached_bufs = reordered
  M.invalidate_cache()
  return reordered
end

--- Swap bufnr one position to the left.
---@param bufnr integer
function M.move_left(bufnr)
  local bufs = M.sync()
  local idx = M.get_index(bufnr)
  if idx and idx > 1 then
    bufs[idx], bufs[idx - 1] = bufs[idx - 1], bufs[idx]
    state.order = bufs
    state.cached_bufs = bufs
    M.invalidate_cache()
  end
end

--- Swap bufnr one position to the right.
---@param bufnr integer
function M.move_right(bufnr)
  local bufs = M.sync()
  local idx = M.get_index(bufnr)
  if idx and idx < #bufs then
    bufs[idx], bufs[idx + 1] = bufs[idx + 1], bufs[idx]
    state.order = bufs
    state.cached_bufs = bufs
    M.invalidate_cache()
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
  if not idx or #bufs <= 1 then
    return nil
  end

  if focus == "right" then
    if idx < #bufs then
      return bufs[idx + 1]
    end
    return bufs[idx - 1]
  elseif focus == "previous" then
    local alt = vim.fn.bufnr("#")
    if alt ~= -1 and alt ~= bufnr and is_valid_listed(alt) then
      return alt
    end
    -- fall through to "left"
  end

  -- Default / "left"
  if idx > 1 then
    return bufs[idx - 1]
  end
  return bufs[2] -- was first; go to what becomes the new first
end

--- Safely delete a buffer via the Neovim API.
---@param bufnr integer
local function delete_buf(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  if not ok then
    vim.notify("tabline: could not delete buffer " .. bufnr .. ": " .. tostring(err), vim.log.levels.WARN)
  end
  M.invalidate_cache()
end

--- Close bufnr, switching away all windows that currently show it.
---@param bufnr  integer
---@param focus  string  "left"|"right"|"previous"
function M.close(bufnr, focus)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local bufs = M.sync()
  if #bufs == 0 then
    return
  end

  -- If this is the last listed buffer, open a blank buffer first
  if #bufs == 1 then
    local replacement = require("custom.ui.buffer").create_raw(true, false)
    if not replacement or not vim.api.nvim_buf_is_valid(replacement) then
      vim.notify("tabline: could not create replacement buffer", vim.log.levels.WARN)
      return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        pcall(vim.api.nvim_win_set_buf, win, replacement)
      end
    end

    delete_buf(bufnr)
    return
  end

  local target = pick_focus_target(bufnr, bufs, focus or "left")

  if target then
    -- Redirect every window in all tabpages showing this buffer
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
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
  local bt = vim.bo[b].buftype
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
    return normalize_path(name), false
  end
end

--- Compute unique, short display names for a list of buffers.
---@param bufs    integer[]
---@param max_len integer   0 = no limit
---@return table<integer, string>
function M.get_display_names(bufs, max_len)
  if #bufs == 0 then
    return {}
  end

  local raw = {}
  local special = {}
  for _, b in ipairs(bufs) do
    raw[b], special[b] = raw_label(b)
  end

  -- Group non-special buffers by their tail (filename)
  local tail_to_bufs = {}
  for _, b in ipairs(bufs) do
    if not special[b] then
      local tail = vim.fn.fnamemodify(raw[b], ":t")
      if tail == "" then
        tail = raw[b]
      end
      tail_to_bufs[tail] = tail_to_bufs[tail] or {}
      tail_to_bufs[tail][#tail_to_bufs[tail] + 1] = b
    end
  end

  local names = {}

  -- Special buffers get their raw label directly
  for _, b in ipairs(bufs) do
    if special[b] then
      names[b] = raw[b]
    end
  end

  -- For each group of same-tailed buffers, extend path until unique
  for _, conflict_bufs in pairs(tail_to_bufs) do
    if #conflict_bufs == 1 then
      local b = conflict_bufs[1]
      names[b] = vim.fn.fnamemodify(raw[b], ":t")
    else
      local displays = {}
      for _, b in ipairs(conflict_bufs) do
        local parts = {}
        for seg in (normalize_path(raw[b]) .. "/"):gmatch("([^/]+)/") do
          parts[#parts + 1] = seg
        end
        displays[b] = { parts = parts, depth = 1 }
      end

      for _ = 1, 8 do
        local cur = {}
        for _, b in ipairs(conflict_bufs) do
          local d = displays[b]
          local n = #d.parts
          local depth = math.min(d.depth, n)
          local seg = {}
          for k = n - depth + 1, n do
            seg[#seg + 1] = d.parts[k]
          end
          cur[b] = table.concat(seg, "/")
        end

        local seen = {}
        local all_unique = true
        for _, b in ipairs(conflict_bufs) do
          if seen[cur[b]] then
            all_unique = false
            break
          end
          seen[cur[b]] = true
        end

        if all_unique then
          for _, b in ipairs(conflict_bufs) do
            names[b] = cur[b]
          end
          break
        end

        local still = {}
        for s, _ in pairs(seen) do
          local cnt = 0
          for _, b in ipairs(conflict_bufs) do
            if cur[b] == s then
              cnt = cnt + 1
            end
          end
          if cnt > 1 then
            for _, b in ipairs(conflict_bufs) do
              if cur[b] == s then
                still[b] = true
              end
            end
          end
        end

        local extended = false
        for _, b in ipairs(conflict_bufs) do
          if still[b] then
            local d = displays[b]
            if d.depth < #d.parts then
              d.depth = d.depth + 1
              extended = true
            end
          end
        end

        if not extended then
          for _, b in ipairs(conflict_bufs) do
            if not names[b] then
              names[b] = cur[b]
            end
          end
          break
        end
      end

      for _, b in ipairs(conflict_bufs) do
        if not names[b] then
          names[b] = vim.fn.fnamemodify(raw[b], ":t")
        end
      end
    end
  end

  for _, b in ipairs(bufs) do
    if not names[b] then
      names[b] = raw[b]
    end
  end

  if max_len and max_len > 0 then
    for _, b in ipairs(bufs) do
      names[b] = truncate_display(names[b], max_len)
    end
  end

  return names
end

return M
