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
    -- For identical quotes, count parity
    local _, count = line:gsub(open, "")
    return count % 2 == 0
  end

  local open_count = 0
  local close_count = 0
  for i = 1, #line do
    local char = line:sub(i, i)
    if char == open then
      open_count = open_count + 1
    elseif char == close then
      close_count = close_count + 1
    end
  end

  return open_count <= close_count
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
      -- Edge case: inside a TSX/JSX template or Lua multiline, pairing might be desired.
      -- However, generally we do not double pair identical quotes inside strings.
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

  -- 5. Line Balance Verification
  -- If we're already balanced or have more closing delimiters, it's safe to close.
  -- If there's already too many closing delimiters downstream, we avoid adding more.
  if not is_balanced(line, open, close) and open ~= close then
    -- Let's check if the downstream text actually contains the closing character.
    -- If there's an unmatched close ahead, don't auto-close.
    local remaining = line:sub(col + 1)
    -- Escape special characters for gsub
    local escaped_close = close:gsub("[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
    local _, close_matches = remaining:gsub(escaped_close, "")
    if close_matches > 0 then
      return false
    end
  end

  return true
end

return M
