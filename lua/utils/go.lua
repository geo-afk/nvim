local M = {}
local ns = vim.api.nvim_create_namespace("go_import_highlight")
local timers = {}

local query = vim.treesitter.query.parse(
  "go",
  [[
  (import_spec
    path: (interpreted_string_literal
      (interpreted_string_literal_content) @path))

  (interpreted_string_literal
    (interpreted_string_literal_content) @format_string)

  (raw_string_literal
    (raw_string_literal_content) @format_string)
]]
)

local FORMAT_VERBS = {}
for verb in ("vTtbcdoOxXUeEfFgGsqpw"):gmatch(".") do
  FORMAT_VERBS[verb] = true
end

local function offset_to_position(text, start_row, start_col, offset)
  local row = start_row
  local col = start_col
  local pos = 1

  while pos <= offset do
    local ch = text:sub(pos, pos)
    if ch == "\n" then
      row = row + 1
      col = 0
    else
      col = col + 1
    end
    pos = pos + 1
  end

  return row, col
end

local function parse_bracket_arg(text, i)
  if text:sub(i, i) ~= "[" then
    return i
  end

  local close = text:find("%]", i + 1)
  if not close then
    return i
  end

  local n = text:sub(i + 1, close - 1)
  if n:match("^%d+$") then
    return close + 1
  end

  return i
end

local function parse_width_or_precision_operand(text, i)
  local after_arg = parse_bracket_arg(text, i)
  if text:sub(after_arg, after_arg) == "*" then
    i = after_arg + 1
  elseif text:sub(i, i) == "*" then
    i = i + 1
  end

  local _, digits_end = text:find("^%d+", i)
  return digits_end and (digits_end + 1) or i
end

local function parse_format_verb(text, i)
  local j = i + 1

  j = parse_bracket_arg(text, j)

  while text:sub(j, j):match("[-+# 0]") do
    j = j + 1
  end

  j = parse_width_or_precision_operand(text, j)

  if text:sub(j, j) == "." then
    j = parse_width_or_precision_operand(text, j + 1)
  end

  return FORMAT_VERBS[text:sub(j, j)] and j or nil
end

local function highlight_format_verbs(bufnr, node)
  local text = vim.treesitter.get_node_text(node, bufnr)
  local start_row, start_col = node:range()
  local i = 1

  while i <= #text do
    local ch = text:sub(i, i)
    if ch ~= "%" then
      i = i + 1
    elseif text:sub(i + 1, i + 1) == "%" then
      i = i + 2
    else
      local format_end = parse_format_verb(text, i)
      if format_end then
        local from_row, from_col = offset_to_position(text, start_row, start_col, i - 1)
        local to_row, to_col = offset_to_position(text, start_row, start_col, format_end)
        vim.api.nvim_buf_set_extmark(bufnr, ns, from_row, from_col, {
          end_row = to_row,
          end_col = to_col,
          hl_group = "Special",
          priority = 210,
        })
        i = format_end + 1
      else
        i = i + 1
      end
    end
  end
end

function M.highlight_go(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "go" then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local capture = query.captures[id]
    if capture == "path" then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local start_row, start_col, _, end_col = node:range()

      -- Find the position of the last slash
      local last_slash = text:find("/[^/]*$")
      local offset = last_slash or 0

      -- Highlight from the slash (or start) to the end of the string
      vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col + offset, {
        end_col = end_col,
        hl_group = "Type", -- You can change this to any group like @module or Keyword
        priority = 200, -- High priority to win over standard string colors
      })
    elseif capture == "format_string" then
      highlight_format_verbs(bufnr, node)
    end
  end
end

M.highlight_imports = M.highlight_go

local function cleanup_timer(bufnr)
  local timer = timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    timers[bufnr] = nil
  end
end

local function debounce_highlight(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local timer = timers[bufnr]
  if not timer then
    timer = vim.uv.new_timer()
    timers[bufnr] = timer
  end

  timer:stop()
  timer:start(
    120,
    0,
    vim.schedule_wrap(function()
      M.highlight_go(bufnr)
    end)
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("GoImportHighlighter", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
    group = group,
    pattern = "*.go",
    callback = function(ev)
      debounce_highlight(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    pattern = "*.go",
    callback = function(ev)
      cleanup_timer(ev.buf)
    end,
  })
end

return M
