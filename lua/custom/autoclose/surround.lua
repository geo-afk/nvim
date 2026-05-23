-- =============================================================================
-- lua/custom/autoclose/surround.lua
-- Visual and Normal mode surrounding utility
-- =============================================================================

local ts = require("custom.autoclose.ts")

local M = {}

-- Delimiter map with spacing rules
local DELIMITER_MAP = {
  ["("] = { open = "( ", close = " )" },
  [")"] = { open = "(", close = ")" },
  ["["] = { open = "[ ", close = " ]" },
  ["]"] = { open = "[", close = "]" },
  ["{"] = { open = "{ ", close = " }" },
  ["}"] = { open = "{", close = "}" },
  ["<"] = { open = "<", close = ">" },
  [">"] = { open = "<", close = ">" },
  ['"'] = { open = '"', close = '"' },
  ["'"] = { open = "'", close = "'" },
  ["`"] = { open = "`", close = "`" },
}

---Resolve open/close strings based on selected delimiter character
---@param char string
---@return string|nil open
---@return string|nil close
local function resolve_delimiters(char)
  if char == "t" or char == "<" then
    -- Interactive tag prompt
    local tag = vim.fn.input("Tag name: ")
    if tag == "" then
      return nil, nil
    end
    return "<" .. tag .. ">", "</" .. tag .. ">"
  end

  local pair = DELIMITER_MAP[char]
  if pair then
    return pair.open, pair.close
  end

  -- Default fallback: wrap with the character itself on both sides
  return char, char
end

---Surrounds visual selection with chosen delimiter
function M.visual_surround()
  -- Exit visual mode to set '< and '> marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)

  vim.schedule(function()
    local start_pos = vim.api.nvim_buf_get_mark(0, "<")
    local end_pos = vim.api.nvim_buf_get_mark(0, ">")
    local start_row, start_col = start_pos[1] - 1, start_pos[2]
    local end_row, end_col = end_pos[1] - 1, end_pos[2]

    -- Ensure valid coordinates
    if start_row < 0 or end_row < 0 then
      return
    end

    -- Visual block end is inclusive, let's adjust end_col to include the last selected character
    local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
    if line then
      end_col = math.min(#line, end_col + 1)
    end

    -- Prompt user for delimiter character
    vim.api.nvim_echo({ { "Delimiter to wrap selection (or t for tag): ", "Question" } }, false, {})
    local char = vim.fn.getcharstr()
    if not char or char == "" or char:byte(1) == 27 then -- ESC check
      vim.api.nvim_echo({ { "Surround cancelled", "WarningMsg" } }, false, {})
      return
    end

    local open_str, close_str = resolve_delimiters(char)
    if not open_str then
      return
    end

    local ok, text = pcall(vim.api.nvim_buf_get_text, 0, start_row, start_col, end_row, end_col, {})
    if not ok or not text then
      return
    end

    -- Prepend open and append close
    text[1] = open_str .. text[1]
    text[#text] = text[#text] .. close_str

    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, text)
  end)
end

---Surrounds the current word under the cursor
function M.word_surround()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local line = vim.api.nvim_get_current_line()

  -- Scan for word boundary
  local cword = vim.fn.expand("<cword>")
  if cword == "" then
    vim.api.nvim_echo({ { "No word found under cursor", "WarningMsg" } }, false, {})
    return
  end

  -- Find start column of the word under cursor
  local start_col = col
  while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
    start_col = start_col - 1
  end
  if start_col > 0 or not line:sub(1, 1):match("[%w_]") then
    start_col = start_col + 1
  end

  local end_col = start_col + #cword

  -- Prompt user for delimiter character
  vim.api.nvim_echo({ { "Delimiter to wrap word (or t for tag): ", "Question" } }, false, {})
  local char = vim.fn.getcharstr()
  if not char or char == "" or char:byte(1) == 27 then
    return
  end

  local open_str, close_str = resolve_delimiters(char)
  if not open_str then
    return
  end

  local text = line:sub(start_col, end_col)
  local new_text = open_str .. text .. close_str

  vim.api.nvim_buf_set_text(0, row, start_col - 1, row, end_col - 1, { new_text })
  -- Reposition cursor to remain inside the word
  vim.api.nvim_win_set_cursor(0, { row + 1, start_col + #open_str - 1 })
end

---Surrounds the current Treesitter node under the cursor
function M.node_surround()
  local node = ts.get_node()
  if not node then
    vim.api.nvim_echo({ { "No Treesitter node found under cursor", "WarningMsg" } }, false, {})
    return
  end

  local start_row, start_col, end_row, end_col = node:range()

  -- Prompt user for delimiter character
  vim.api.nvim_echo({ { "Delimiter to wrap Treesitter node (or t for tag): ", "Question" } }, false, {})
  local char = vim.fn.getcharstr()
  if not char or char == "" or char:byte(1) == 27 then
    return
  end

  local open_str, close_str = resolve_delimiters(char)
  if not open_str then
    return
  end

  local text = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
  text[1] = open_str .. text[1]
  text[#text] = text[#text] .. close_str

  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, text)
end

---Find the closest matching pair enclosing the cursor on the current line
---@return integer|nil open_idx
---@return integer|nil close_idx
---@return string|nil char
local function find_surrounding_pair()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed for string ops

  local pairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
  }

  -- Scan outwards
  local left = col - 1
  local right = col

  while left >= 1 and right <= #line do
    local lchar = line:sub(left, left)
    local rchar = line:sub(right, right)

    if pairs[lchar] == rchar then
      return left, right, lchar
    end

    -- Expand search window intelligently
    if pairs[lchar] then
      right = right + 1
    else
      left = left - 1
    end
  end

  return nil, nil, nil
end

---Delete the nearest surrounding pair
function M.delete_surround()
  local open_idx, close_idx = find_surrounding_pair()
  if not open_idx or not close_idx then
    vim.api.nvim_echo({ { "No surrounding pair found on line", "WarningMsg" } }, false, {})
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Delete closing character first to preserve indexing of the opening one
  vim.api.nvim_buf_set_text(0, row, close_idx - 1, row, close_idx, {})
  vim.api.nvim_buf_set_text(0, row, open_idx - 1, row, open_idx, {})
end

---Replace the nearest surrounding pair
function M.replace_surround()
  local open_idx, close_idx, old_char = find_surrounding_pair()
  if not open_idx or not close_idx or not old_char then
    vim.api.nvim_echo({ { "No surrounding pair found on line", "WarningMsg" } }, false, {})
    return
  end

  -- Prompt user for new delimiter character
  vim.api.nvim_echo({ { "New delimiter character: ", "Question" } }, false, {})
  local char = vim.fn.getcharstr()
  if not char or char == "" or char:byte(1) == 27 then
    return
  end

  local open_str, close_str = resolve_delimiters(char)
  if not open_str then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Perform replacement
  vim.api.nvim_buf_set_text(0, row, close_idx - 1, row, close_idx, { close_str })
  vim.api.nvim_buf_set_text(0, row, open_idx - 1, row, open_idx, { open_str })
end

return M
