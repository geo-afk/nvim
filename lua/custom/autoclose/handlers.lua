-- =============================================================================
-- lua/custom/autoclose/handlers.lua
-- Keyboard handlers for backspace, carriage return, and skip-over
-- =============================================================================

local config = require("custom.autoclose.config")

local M = {}

---Smart backspace handler to delete matching pairs
---@return string
function M.handle_backspace()
  if not config.get("enabled") then
    return "<BS>"
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed byte offset
  local char_before = col > 0 and line:sub(col, col) or ""
  local char_after = line:sub(col + 1, col + 1)

  local pairs = config.get("pairs")
  if pairs[char_before] == char_after then
    return "<BS><Del>"
  end

  return "<BS>"
end

---Smart carriage return expansion for open pairs (e.g. { | } or [ | ])
---@return string
function M.handle_cr()
  if not config.get("enabled") then
    return "<CR>"
  end

  -- Avoid carriage return interference when completion popup is active
  local ok_blink, blink = pcall(require, "blink.cmp")
  if ok_blink and blink.is_visible() then
    return "<CR>"
  end

  if vim.fn.pumvisible() ~= 0 then
    return "<CR>"
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local char_before = col > 0 and line:sub(col, col) or ""
  local char_after = line:sub(col + 1, col + 1)

  local cr_pairs = {
    ["{"] = "}",
    ["["] = "]",
    ["("] = ")",
  }

  if cr_pairs[char_before] == char_after then
    -- Expands open/close delimiters to 3 lines and places cursor on the middle indented line
    return "<CR><Esc>O"
  end

  -- Tag expansion: <tag>|</tag>
  if char_before == ">" and char_after == "<" then
    local prev_text = line:sub(1, col)
    local next_text = line:sub(col + 1)
    if prev_text:match("<%w+>$") and next_text:match("^</%w+>") then
      return "<CR><Esc>O"
    end
  end

  return "<CR>"
end

---Smart skip-over handler for closing delimiters
---@param char string The typed character
---@return string
function M.handle_close(char)
  if not config.get("enabled") then
    return char
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local next_char = line:sub(col + 1, col + 1)

  if char == next_char then
    return "<Right>"
  end

  return char
end

---Smart tag autoclose handler
---@return string|nil
function M.handle_tag_close()
  if not config.get("enabled") then
    return ">"
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = line:sub(1, col)

  -- Match an opening tag like <div> but not a self-closing one like <img />
  local tag_name = before:match("<([%w%-]+)[^>]*$")
  if tag_name and not before:match("/$") then
    -- Check if it's a void element (HTML specific)
    local void_elements = {
      area = true,
      base = true,
      br = true,
      col = true,
      embed = true,
      hr = true,
      img = true,
      input = true,
      link = true,
      meta = true,
      param = true,
      source = true,
      track = true,
      wbr = true,
    }
    if void_elements[tag_name:lower()] then
      return ">"
    end

    return ">" .. "</" .. tag_name .. ">" .. string.rep("<Left>", #tag_name + 3)
  end

  return ">"
end

return M
