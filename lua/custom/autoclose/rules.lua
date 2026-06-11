-- =============================================================================
-- lua/custom/autoclose/rules.lua
-- Smart rules for context verification
-- =============================================================================

local config = require("custom.autoclose.config")
local ts = require("custom.autoclose.ts")

local M = {}

---Check if delimiters on the line are balanced
---@param line string
---@param open string
---@param close string
---@return boolean
local function is_balanced(line, open, close)
  if open == close then
    -- For identical quotes, count parity (excluding escaped ones)
    local count = 0
    local i = 1
    while i <= #line do
      local ch = line:sub(i, i)
      if ch == "\\" then
        -- Skip escaped character
        i = i + 2
      elseif ch == open then
        count = count + 1
        i = i + 1
      else
        i = i + 1
      end
    end
    return count % 2 == 0
  end

  local depth = 0
  local i = 1
  while i <= #line do
    local ch = line:sub(i, i)
    if ch == "\\" then
      i = i + 2
    elseif ch == open then
      depth = depth + 1
      i = i + 1
    elseif ch == close then
      depth = depth - 1
      i = i + 1
    else
      i = i + 1
    end
  end

  return depth <= 0
end

---Validate if it is safe to autoclose given the context
---@param open string
---@param close string
---@return boolean
function M.can_close(open, close)
  -- 1. Global Enable Check
  if not config.get("enabled") then
    return false
  end

  -- 2. Filetype Exclusions
  if vim.tbl_contains(config.get("disable_filetypes"), vim.bo.filetype) then
    return false
  end

  -- 3. Treesitter Context Checking
  local node = ts.get_node()
  local ignored_nodes = config.get("ignored_nodes")
  if ts.in_comment(ignored_nodes, node) then
    return false
  end

  -- Quote triggers inside string contexts should be ignored to prevent nesting quotes
  if open == close then
    local ignored_quote = config.get("ignored_quote_nodes")
    if ts.in_string(ignored_quote, node) then
      return false
    end
  end

  -- 4. Line and Cursor Context Checking
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed byte offset
  local prev_char = col > 0 and line:sub(col, col) or ""
  local next_char = line:sub(col + 1, col + 1)

  -- Don't pair if the next character is alphanumeric or an underscore
  -- (e.g. typing '(' inside 'word' -> 'w(ord')
  if next_char:match("[%w_]") then
    return false
  end

  -- Don't pair if we are right after an escape backslash (e.g. typing '(' after '\' -> '\(')
  if prev_char == "\\" then
    return false
  end

  -- For identical pairs (quotes): don't pair if the next char is the same quote
  -- (the caller will handle skip-over separately)
  if open == close and next_char == close then
    return false
  end

  -- Don't pair quotes right after a word character (e.g. it's, don't)
  if open == close and prev_char:match("[%w_]") then
    return false
  end

  -- 5. Line Balance Verification
  if not is_balanced(line, open, close) then
    return false
  end

  return true
end

return M
