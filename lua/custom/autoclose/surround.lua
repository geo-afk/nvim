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
  -- Backtrack while on word characters
  while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
    start_col = start_col - 1
  end
  -- If we're not at start of line, increment to point to the first word char
  if start_col > 0 or not line:sub(1, 1):match("[%w_]") then
    start_col = start_col + 1
  end

  local end_col = start_col + #cword - 1

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

  -- nvim_buf_set_text uses 0-indexed columns, end is exclusive
  -- start_col-1 is the 0-indexed start.
  local s_col = math.max(0, start_col - 1)
  local e_col = s_col + #cword

  local text = line:sub(start_col, start_col + #cword - 1)
  local new_text = open_str .. text .. close_str

  vim.api.nvim_buf_set_text(0, row, s_col, row, e_col, { new_text })
  -- Reposition cursor to remain inside the word
  vim.api.nvim_win_set_cursor(0, { row + 1, s_col + #open_str })
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

  local ok, text = pcall(vim.api.nvim_buf_get_text, 0, start_row, start_col, end_row, end_col, {})
  if not ok then
    return
  end

  text[1] = open_str .. text[1]
  text[#text] = text[#text] .. close_str

  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, text)
end

---Find the closest matching pair enclosing the cursor using Treesitter
---@return integer[]|nil start_pos {row, col}
---@return integer[]|nil end_pos {row, col}
---@return string|nil old_char
local function find_surrounding_pair()
  local node = ts.get_pair_node()
  if not node then
    return nil, nil, nil
  end

  local start_row, start_col, end_row, end_col = node:range()

  -- Get the actual characters at the boundaries to identify the pair
  local ok, start_text = pcall(vim.api.nvim_buf_get_text, 0, start_row, start_col, start_row, start_col + 1, {})
  if not ok or not start_text[1] then
    return nil, nil, nil
  end

  return { start_row, start_col }, { end_row, end_col }, start_text[1]
end

---Delete the nearest surrounding pair
function M.delete_surround()
  local start_pos, end_pos = find_surrounding_pair()
  if not start_pos or not end_pos then
    vim.api.nvim_echo({ { "No surrounding pair found", "WarningMsg" } }, false, {})
    return
  end

  local node = ts.get_pair_node()
  if not node then
    return
  end

  -- For tags (elements), the delimiters are usually the first and last children
  local first = node:child(0)
  local last = node:child(node:child_count() - 1)

  -- Ensure we don't delete the same node twice if it's a leaf
  if first and last and first:id() ~= last:id() then
    local f_sr, f_sc, f_er, f_ec = first:range()
    local l_sr, l_sc, l_er, l_ec = last:range()

    -- Delete closing first
    vim.api.nvim_buf_set_text(0, l_sr, l_sc, l_er, l_ec, {})
    vim.api.nvim_buf_set_text(0, f_sr, f_sc, f_er, f_ec, {})
  else
    -- Fallback to single character deletion from range
    -- start_pos[1], start_pos[2] is the row, col of the opener
    -- end_pos[1], end_pos[2] is the row, col AFTER the closer
    vim.api.nvim_buf_set_text(0, end_pos[1], end_pos[2] - 1, end_pos[1], end_pos[2], {})
    vim.api.nvim_buf_set_text(0, start_pos[1], start_pos[2], start_pos[1], start_pos[2] + 1, {})
  end
end

---Replace the nearest surrounding pair
function M.replace_surround()
  local start_pos, end_pos, old_char = find_surrounding_pair()
  if not start_pos or not end_pos then
    vim.api.nvim_echo({ { "No surrounding pair found", "WarningMsg" } }, false, {})
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

  local node = ts.get_pair_node()
  if not node then
    return
  end

  local first = node:child(0)
  local last = node:child(node:child_count() - 1)

  if first and last and first:id() ~= last:id() then
    local f_sr, f_sc, f_er, f_ec = first:range()
    local l_sr, l_sc, l_er, l_ec = last:range()

    vim.api.nvim_buf_set_text(0, l_sr, l_sc, l_er, l_ec, { close_str })
    vim.api.nvim_buf_set_text(0, f_sr, f_sc, f_er, f_ec, { open_str })
  else
    vim.api.nvim_buf_set_text(0, end_pos[1], end_pos[2] - 1, end_pos[1], end_pos[2], { close_str })
    vim.api.nvim_buf_set_text(0, start_pos[1], start_pos[2], start_pos[1], start_pos[2] + 1, { open_str })
  end
end

return M
