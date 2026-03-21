-- nvim-cmdline/preview.lua
-- Live buffer preview as the user types commands.
--
-- Supported commands:
--   [range]s/pattern/replacement/[flags]   substitute (highlight matches + show replacement)
--   [range]g/pattern/[cmd]                 global     (highlight matching lines)
--   [range]v/pattern/[cmd]                 vglobal    (highlight non-matching lines)
--   [range]d[elete]                        delete     (highlight lines to be deleted)
--   [range]y[ank]                          yank       (highlight lines to be yanked)
--
-- Uses extmarks only — buffer text is NEVER modified.
-- All marks are cleared on cmdline close or Esc.

local M = {}

-- Two namespaces so we can clear them independently
local NS_MATCH = vim.api.nvim_create_namespace("nvim_cmdline_preview_match")
local NS_REPLACE = vim.api.nvim_create_namespace("nvim_cmdline_preview_replace")

-- Detect Neovim 0.10+ for inline virt_text support
local HAS_INLINE = vim.fn.has("nvim-0.10") == 1

-- Max lines to scan for matches (performance guard)
local MAX_SCAN_LINES = 500

-- ---------------------------------------------------------------------------
-- Highlight group setup (called from colors.setup_highlights)
-- ---------------------------------------------------------------------------

function M.setup_highlights()
  -- Match: the text that WILL be replaced/deleted (dim + strikethrough)
  local ok1, hl = pcall(vim.api.nvim_get_hl, 0, { name = "DiagnosticError", link = false })
  local err_fg = (ok1 and hl.fg) and string.format("#%06x", hl.fg) or "#f38ba8"

  local ok2, hl2 = pcall(vim.api.nvim_get_hl, 0, { name = "DiagnosticOk", link = false })
  if not ok2 then
    ok2, hl2 = pcall(vim.api.nvim_get_hl, 0, { name = "DiagnosticHint", link = false })
  end
  local ok_fg = (ok2 and hl2.fg) and string.format("#%06x", hl2.fg) or "#a6e3a1"

  local ok3, hl3 = pcall(vim.api.nvim_get_hl, 0, { name = "DiffDelete", link = false })
  local del_bg = (ok3 and hl3.bg) and string.format("#%06x", hl3.bg) or "#3d1a1a"

  local ok4, hl4 = pcall(vim.api.nvim_get_hl, 0, { name = "DiffAdd", link = false })
  local add_bg = (ok4 and hl4.bg) and string.format("#%06x", hl4.bg) or "#1a3d1a"

  local ok5, hl5 = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  local norm_bg = (ok5 and hl5.bg) and string.format("#%06x", hl5.bg) or "#1e1e2e"

  -- The part of the line that will be removed
  vim.api.nvim_set_hl(0, "NvimCmdlinePreviewDel", {
    fg = err_fg,
    bg = del_bg,
    strikethrough = true,
  })

  -- The replacement text shown as virtual text
  vim.api.nvim_set_hl(0, "NvimCmdlinePreviewAdd", {
    fg = ok_fg,
    bg = add_bg,
  })

  -- Whole-line highlight for :g/:v/:d/:y
  vim.api.nvim_set_hl(0, "NvimCmdlinePreviewLine", {
    bg = del_bg,
  })

  -- Yank line highlight (gentler)
  vim.api.nvim_set_hl(0, "NvimCmdlinePreviewYank", {
    bg = add_bg,
  })

  -- Counter badge background
  vim.api.nvim_set_hl(0, "NvimCmdlinePreviewCount", {
    fg = ok_fg,
    bold = true,
  })
end

-- ---------------------------------------------------------------------------
-- Range resolver
-- ---------------------------------------------------------------------------

---Resolve a Vim range string to {first, last} 1-based line numbers.
---Returns nil if the range is invalid or empty.
---@param range_str string   e.g. "%", "1,5", "'<,'>", "."
---@param buf       integer  target buffer
---@return integer|nil first
---@return integer|nil last
local function resolve_range(range_str, buf)
  if type(range_str) ~= "string" then
    return nil
  end
  local total = vim.api.nvim_buf_line_count(buf)
  if range_str == "" or range_str == "." then
    -- Current line (in the prev_win context, caller handles this)
    return 1, total -- safe default; actual current line resolved by caller
  end
  if range_str == "%" then
    return 1, total
  end

  -- Try to evaluate each side through nvim_eval
  local lo_str = range_str:match("^([^,]+)") or range_str
  local hi_str = range_str:match(",(.+)$") or lo_str

  local function eval_line(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    -- Simple number
    local n = tonumber(s)
    if n then
      return math.max(1, math.min(n, total))
    end
    -- Special marks / $ / . handled via line()
    local ok, v = pcall(vim.fn.line, s)
    if ok and type(v) == "number" and v > 0 then
      return math.min(v, total)
    end
    return nil
  end

  local lo = eval_line(lo_str)
  local hi = eval_line(hi_str)
  if not lo or not hi then
    return nil
  end
  return math.min(lo, hi), math.max(lo, hi)
end

-- ---------------------------------------------------------------------------
-- Substitute command parser
-- ---------------------------------------------------------------------------

---@class SubstParsed
---@field range     string
---@field pattern   string
---@field replacement string
---@field flags     string
---@field delimiter string

---Parse :[range]s/pat/rep/flags.  Returns nil when the command is incomplete.
---@param input string
---@return SubstParsed|nil
local function parse_substitute(input)
  if type(input) ~= "string" then
    return nil
  end

  -- Match: [range] s[ubstitute] <delim> <pattern> [<delim> [<replacement>] [<delim> [flags]]]
  local range, rest = input:match("^([%%%.%$%d,'<>%+%-]*)%s*s%a*(.*)$")
  if not rest or rest == "" then
    return nil
  end

  local delim = rest:sub(1, 1)
  if delim == "" or delim:match("[%w%s]") then
    return nil
  end -- not a valid delimiter

  -- Split by delimiter (handle escaped delimiters)
  local parts = {}
  local current = ""
  local i = 2 -- skip the first delimiter
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
  -- Anything remaining is the last part (incomplete command is fine)
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
---@field range   string
---@field pattern string
---@field invert  boolean   true for :v
---@field cmd     string

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
    -- plain :d or :y with no range = current line only, not interesting to preview
    return nil
  end
  return { range = range, verb = verb }
end

-- ---------------------------------------------------------------------------
-- Apply substitute preview
-- ---------------------------------------------------------------------------

---Apply match highlights and replacement virt_text for a substitute command.
---@param buf    integer  target buffer
---@param parsed SubstParsed
---@param first  integer  first line (1-based)
---@param last   integer  last line (1-based)
local function apply_substitute_preview(buf, parsed, first, last)
  if parsed.pattern == "" then
    return
  end

  -- Build the Vim regex from the pattern
  local ok_re, re = pcall(vim.regex, parsed.pattern)
  if not ok_re or not re then
    return
  end

  local global_flag = parsed.flags:find("g") ~= nil
  local count = 0

  for lnum = first, math.min(last, first + MAX_SCAN_LINES) do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not line then
      break
    end

    local col = 0
    local line_matched = false

    while col <= #line do
      local ms, me = re:match_str(line:sub(col + 1))
      if not ms then
        break
      end

      local abs_ms = col + ms
      local abs_me = col + me -- exclusive

      -- Highlight the matched region (the part being replaced)
      pcall(vim.api.nvim_buf_set_extmark, buf, NS_MATCH, lnum - 1, abs_ms, {
        end_col = abs_me,
        hl_group = "NvimCmdlinePreviewDel",
        priority = 200,
      })

      -- Show replacement as virtual text after the match
      if parsed.replacement ~= "" then
        -- Resolve basic back-references (\1, \0, &)
        local rep = parsed.replacement:gsub("\\0", line:sub(abs_ms + 1, abs_me)):gsub("&", line:sub(abs_ms + 1, abs_me))

        -- Choose virt_text position: inline (0.10+) or right-aligned eol
        if HAS_INLINE then
          pcall(vim.api.nvim_buf_set_extmark, buf, NS_REPLACE, lnum - 1, abs_ms, {
            virt_text = { { rep, "NvimCmdlinePreviewAdd" } },
            virt_text_pos = "inline",
            priority = 201,
          })
        else
          -- Fallback: show replacement at eol with an arrow
          pcall(vim.api.nvim_buf_set_extmark, buf, NS_REPLACE, lnum - 1, 0, {
            virt_text = { { " → " .. rep, "NvimCmdlinePreviewAdd" } },
            virt_text_pos = "eol",
            priority = 201,
          })
        end
      end

      count = count + 1
      line_matched = true

      -- Without 'g' flag, only replace first match per line
      if not global_flag then
        break
      end

      -- Advance past this match (handle zero-length match)
      local advance = (abs_me > abs_ms) and abs_me or (abs_ms + 1)
      if advance <= col then
        break
      end -- safety
      col = advance
    end
    _ = line_matched
  end

  return count
end

-- ---------------------------------------------------------------------------
-- Apply global/vglobal preview
-- ---------------------------------------------------------------------------

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
---@param win integer|nil   the original window (prev_win)
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
---Called (debounced) every time the cmdline input changes.
---@param input string   current input text (prompt prefix already stripped)
---@param win   integer  prev_win handle
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

  -- Always clear previous marks first
  vim.api.nvim_buf_clear_namespace(buf, NS_MATCH, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, NS_REPLACE, 0, -1)

  -- ── Substitute ──────────────────────────────────────────────────────────
  local subst = parse_substitute(input)
  if subst then
    -- We need line() calls to resolve marks like '<,'> — run in win context
    local first, last
    pcall(vim.api.nvim_win_call, win, function()
      first, last = resolve_range(subst.range, buf)
    end)
    if first and last then
      apply_substitute_preview(buf, subst, first, last)
    end
    return
  end

  -- ── Global / vglobal ────────────────────────────────────────────────────
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

  -- ── Delete / yank ───────────────────────────────────────────────────────
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
