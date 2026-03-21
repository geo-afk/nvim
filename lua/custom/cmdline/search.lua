-- nvim-cmdline/search.lua
-- Live search: hlsearch preview, searchcount in the original window context,
-- commit and cancel.

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Escape a literal delimiter so it doesn't split the /<pattern>/ command.
---@param pattern   string
---@param delimiter string  "/" | "?"
---@return string
local function escape_delim(pattern, delimiter)
  if type(pattern) ~= "string" then
    return ""
  end
  if type(delimiter) ~= "string" then
    return pattern
  end
  return pattern:gsub(vim.pesc(delimiter), "\\" .. delimiter)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Update hlsearch and return the match-count for `pattern`.
---
---`prev_win` is the window that was active BEFORE the cmdline opened; running
---searchcount there ensures "current" reflects the file cursor, not the
---floating cmdline cursor (which lives in its own 1-line scratch buffer).
---
---@param pattern   string
---@param direction string        "/" | "?"
---@param prev_win  integer|nil   original window handle (optional)
---@return { current:integer, total:integer, incomplete:boolean }
function M.update(pattern, direction, prev_win)
  -- Type guards
  if type(pattern) ~= "string" or pattern == "" then
    vim.opt.hlsearch = false
    return { current = 0, total = 0, incomplete = false }
  end

  -- Prime the search register so hlsearch lights up immediately
  pcall(vim.fn.setreg, "/", pattern)
  vim.opt.hlsearch = true

  -- Run searchcount in the correct window context
  local sc = {}
  local function do_count()
    local ok, result = pcall(vim.fn.searchcount, {
      recompute = true,
      maxcount = 1000,
      pattern = pattern,
    })
    if ok and type(result) == "table" then
      sc = result
    end
  end

  if type(prev_win) == "number" and vim.api.nvim_win_is_valid(prev_win) then
    pcall(vim.api.nvim_win_call, prev_win, do_count)
  else
    do_count()
  end

  return {
    current = type(sc.current) == "number" and sc.current or 0,
    total = type(sc.total) == "number" and sc.total or 0,
    incomplete = type(sc.incomplete) == "number" and sc.incomplete == 1 or false,
  }
end

---Execute the search and keep hlsearch on.
---@param pattern   string
---@param direction string  "/" | "?"
function M.commit(pattern, direction)
  if type(pattern) ~= "string" or pattern == "" then
    return
  end
  if type(direction) ~= "string" or direction == "" then
    return
  end

  local escaped = escape_delim(pattern, direction)
  local ok, err = pcall(vim.cmd, direction .. escaped)
  if not ok then
    vim.notify(
      ("[nvim-cmdline] search error: %s"):format(tostring(err)),
      vim.log.levels.WARN,
      { title = "nvim-cmdline" }
    )
  end
  vim.opt.hlsearch = true
end

---Cancel an in-progress search: clear hlsearch and reset the register.
function M.cancel()
  vim.opt.hlsearch = false
  pcall(vim.fn.setreg, "/", "")
end

---Format the counter label, e.g. "[3/20]" or "[no match]".
---@param count { current:integer, total:integer, incomplete:boolean }|nil
---@return string  label
---@return string  hl_group name
function M.counter_label(count)
  if type(count) ~= "table" then
    return "  [?]  ", "NvimCmdlineCounterNone"
  end
  local total = type(count.total) == "number" and count.total or 0
  if total == 0 then
    return "  [no match]  ", "NvimCmdlineCounterNone"
  end
  local current = type(count.current) == "number" and count.current or 0
  local suffix = count.incomplete and "+" or ""
  return ("  [%d/%d%s]  "):format(current, total, suffix), "NvimCmdlineCounter"
end

return M
