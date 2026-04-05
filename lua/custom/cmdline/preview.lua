-- nvim-cmdline/preview.lua
-- Live buffer preview as the user types commands.

local M = {}

local NS_MATCH = vim.api.nvim_create_namespace("nvim_cmdline_preview_match")
local NS_REPLACE = vim.api.nvim_create_namespace("nvim_cmdline_preview_replace")

local HAS_INLINE = vim.fn.has("nvim-0.10") == 1
local MAX_SCAN_LINES = 500

-- ---------------------------------------------------------------------------
-- Range resolver
-- ---------------------------------------------------------------------------

---@param range_str string
---@param buf       integer
---@return integer|nil first
---@return integer|nil last
local function resolve_range(range_str, buf)
  if type(range_str) ~= "string" then
    return nil, nil
  end
  local total = vim.api.nvim_buf_line_count(buf)
  if range_str == "" or range_str == "." then
    return 1, total
  end
  if range_str == "%" then
    return 1, total
  end

  local lo_str = range_str:match("^([^,]+)") or range_str
  local hi_str = range_str:match(",(.+)$") or lo_str

  local function eval_line(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(s)
    if n then
      return math.max(1, math.min(n, total))
    end
    local ok, v = pcall(vim.fn.line, s)
    if ok and type(v) == "number" and v > 0 then
      return math.min(v, total)
    end
    return nil
  end

  local lo = eval_line(lo_str)
  local hi = eval_line(hi_str)
  if not lo or not hi then
    return nil, nil
  end
  return math.min(lo, hi), math.max(lo, hi)
end

-- ---------------------------------------------------------------------------
-- Substitute command parser
-- ---------------------------------------------------------------------------

---@class SubstParsed
---@field range string
---@field pattern string
---@field replacement string
---@field flags string
---@field delimiter string

---@param input string
---@return SubstParsed|nil
local function parse_substitute(input)
  if type(input) ~= "string" then
    return nil
  end

  local range, rest = input:match("^([%%%.%$%d,'<>%+%-]*)%s*s%a*(.*)$")
  if not rest or rest == "" then
    return nil
  end

  local delim = rest:sub(1, 1)
  if delim == "" or delim:match("[%w%s]") then
    return nil
  end

  local parts = {}
  local current = ""
  local i = 2
  while i <= #rest do
    local ch = rest:sub(i, i)
    if ch == "\\" and i < #rest then
      current = current .. ch .. rest:sub(i + 1, i + 1)
      i = i + 2
    elseif ch == delim then
      parts[#parts + 1] = current
      current = ""
      i = i + 1
    else
      current = current .. ch
      i = i + 1
    end
  end
  if current ~= "" or #parts == 0 then
    parts[#parts + 1] = current
  end

  return {
    range = range or "",
    pattern = parts[1] or "",
    replacement = parts[2] or "",
    flags = parts[3] or "",
    delimiter = delim,
  }
end

-- ---------------------------------------------------------------------------
-- Global/vglobal parser
-- ---------------------------------------------------------------------------

---@class GlobalParsed
---@field range string
---@field pattern string
---@field invert boolean
---@field cmd string

local function parse_global(input)
  if type(input) ~= "string" then
    return nil
  end
  local range, gv, rest = input:match("^([%%%.%$%d,'<>%+%-]*)%s*([gv])%a*(.*)$")
  if not gv then
    return nil
  end
  if not rest or rest == "" then
    return nil
  end
  local delim = rest:sub(1, 1)
  if delim == "" or delim:match("[%w%s]") then
    return nil
  end
  local pattern = rest:match("^.(.-)%" .. delim .. "(.*)$") or rest:sub(2)
  return {
    range = range or "",
    pattern = pattern,
    invert = gv == "v",
    cmd = "",
  }
end

-- ---------------------------------------------------------------------------
-- Delete/yank parser
-- ---------------------------------------------------------------------------

local function parse_delete_yank(input)
  if type(input) ~= "string" then
    return nil
  end
  local range, verb = input:match("^([%%%.%$%d,'<>%+%-]+)%s*([dy])%a*%s*$")
  if not range or not verb then
    return nil
  end
  return { range = range, verb = verb }
end

-- ---------------------------------------------------------------------------
-- Apply substitute preview
-- ---------------------------------------------------------------------------

---@param buf integer
---@param parsed SubstParsed
---@param first integer
---@param last integer
---@return integer
local function apply_substitute_preview(buf, parsed, first, last)
  if parsed.pattern == "" then
    return 0
  end

  local ok_re, re = pcall(vim.regex, parsed.pattern)
  if not ok_re or not re then
    return 0
  end

  local global_flag = parsed.flags:find("g") ~= nil
  local count = 0

  for lnum = first, math.min(last, first + MAX_SCAN_LINES) do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not line then
      break
    end

    local col = 0
    while col <= #line do
      local ms, me = re:match_str(line:sub(col + 1))
      if not ms then
        break
      end

      local abs_ms = col + ms
      local abs_me = col + me

      pcall(vim.api.nvim_buf_set_extmark, buf, NS_MATCH, lnum - 1, abs_ms, {
        end_col = abs_me,
        hl_group = "NvimCmdlinePreviewDel",
        priority = 200,
      })

      if parsed.replacement ~= "" then
        local rep = parsed.replacement:gsub("\\0", line:sub(abs_ms + 1, abs_me)):gsub("&", line:sub(abs_ms + 1, abs_me))

        if HAS_INLINE then
          pcall(vim.api.nvim_buf_set_extmark, buf, NS_REPLACE, lnum - 1, abs_ms, {
            virt_text = { { rep, "NvimCmdlinePreviewAdd" } },
            virt_text_pos = "inline",
            priority = 201,
          })
        else
          pcall(vim.api.nvim_buf_set_extmark, buf, NS_REPLACE, lnum - 1, 0, {
            virt_text = { { " → " .. rep, "NvimCmdlinePreviewAdd" } },
            virt_text_pos = "eol",
            priority = 201,
          })
        end
      end

      count = count + 1

      if not global_flag then
        break
      end

      local advance = (abs_me > abs_ms) and abs_me or (abs_ms + 1)
      if advance <= col then
        break
      end
      col = advance
    end
  end

  return count
end

-- ---------------------------------------------------------------------------
-- Apply global/vglobal preview
-- ---------------------------------------------------------------------------

---@param buf integer
---@param parsed GlobalParsed
---@param first integer
---@param last integer
---@return integer
local function apply_global_preview(buf, parsed, first, last)
  if parsed.pattern == "" then
    return 0
  end
  local ok_re, re = pcall(vim.regex, parsed.pattern)
  if not ok_re or not re then
    return 0
  end

  local count = 0
  for lnum = first, math.min(last, first + MAX_SCAN_LINES) do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not line then
      break
    end
    local matched = re:match_str(line) ~= nil
    local should_hl = (matched and not parsed.invert) or (not matched and parsed.invert)
    if should_hl then
      pcall(vim.api.nvim_buf_set_extmark, buf, NS_MATCH, lnum - 1, 0, {
        line_hl_group = "NvimCmdlinePreviewLine",
        priority = 200,
      })
      count = count + 1
    end
  end
  return count
end

-- ---------------------------------------------------------------------------
-- Apply delete/yank preview
-- ---------------------------------------------------------------------------

---@param buf integer
---@param first integer
---@param last integer
---@param is_yank boolean
---@return integer
local function apply_range_preview(buf, first, last, is_yank)
  local hl = is_yank and "NvimCmdlinePreviewYank" or "NvimCmdlinePreviewLine"
  local count = 0
  for lnum = first, math.min(last, first + MAX_SCAN_LINES) do
    local ok, _ = pcall(vim.api.nvim_buf_set_extmark, buf, NS_MATCH, lnum - 1, 0, {
      line_hl_group = hl,
      priority = 200,
    })
    if ok then
      count = count + 1
    end
  end
  return count
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Clear all preview marks from the buffer visible in `win`.
---@param win integer|nil
function M.clear(win)
  if type(win) ~= "number" or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, NS_MATCH, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, NS_REPLACE, 0, -1)
end

---Update the live preview for `input` in the buffer shown by `win`.
---@param input string
---@param win integer
function M.update(input, win)
  if type(input) ~= "string" then
    return
  end
  if type(win) ~= "number" or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, NS_MATCH, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, NS_REPLACE, 0, -1)

  local subst = parse_substitute(input)
  if subst then
    local first, last
    pcall(vim.api.nvim_win_call, win, function()
      first, last = resolve_range(subst.range, buf)
    end)
    if first and last then
      apply_substitute_preview(buf, subst, first, last)
    end
    return
  end

  local glob = parse_global(input)
  if glob then
    local first, last
    pcall(vim.api.nvim_win_call, win, function()
      first, last = resolve_range(glob.range, buf)
    end)
    if first and last then
      apply_global_preview(buf, glob, first, last)
    end
    return
  end

  local dy = parse_delete_yank(input)
  if dy then
    local first, last
    pcall(vim.api.nvim_win_call, win, function()
      first, last = resolve_range(dy.range, buf)
    end)
    if first and last then
      apply_range_preview(buf, first, last, dy.verb == "y")
    end
    return
  end
end

return M
