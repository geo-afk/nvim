-- nvim-cmdline/history.lua
-- Thin wrapper around Vim's native command/search history.
-- Using vim.fn.histget/histadd keeps us in sync with q: / q/ etc.

local M = {}

-- Per-history-type navigation cursor.
-- 0 = no entry selected (user is editing a fresh line).
local cursors = {}

---Reset the navigation cursor for a history type.
---@param hist_type string  ":" | "/" | "?" | "@" | "="
function M.reset(hist_type)
  if type(hist_type) == "string" then
    cursors[hist_type] = 0
  end
end

---Navigate one step older in history.
---@param hist_type string
---@return string|nil  nil when already at the oldest entry
function M.older(hist_type)
  if type(hist_type) ~= "string" then
    return nil
  end
  cursors[hist_type] = (cursors[hist_type] or 0) + 1

  local ok, entry = pcall(vim.fn.histget, hist_type, -cursors[hist_type])
  if not ok or type(entry) ~= "string" or entry == "" then
    -- Out of range — clamp back
    cursors[hist_type] = cursors[hist_type] - 1
    return nil
  end
  return entry
end

---Navigate one step newer in history.
---Returns nil when at the newest end (caller should restore the blank line).
---@param hist_type string
---@return string|nil
function M.newer(hist_type)
  if type(hist_type) ~= "string" then
    return nil
  end
  local cursor = cursors[hist_type] or 0
  if cursor <= 0 then
    return nil
  end

  cursors[hist_type] = cursor - 1
  if cursors[hist_type] == 0 then
    return nil
  end

  local ok, entry = pcall(vim.fn.histget, hist_type, -cursors[hist_type])
  if not ok or type(entry) ~= "string" or entry == "" then
    return nil
  end
  return entry
end

---Add an entry to Vim's native history (shared with q: / q/).
---@param hist_type string
---@param entry     string
function M.add(hist_type, entry)
  if type(hist_type) == "string" and type(entry) == "string" and entry ~= "" then
    pcall(vim.fn.histadd, hist_type, entry)
  end
end

return M
