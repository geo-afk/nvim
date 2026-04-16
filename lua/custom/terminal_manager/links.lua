--------------------------------------------------------------------------------
-- custom/terminal_manager/links.lua
-- Detect URLs and file:line references in terminal buffers.
-- Highlights them with extmarks and provides:
--   gx  → open URL in browser
--   gf  → open file:line in Neovim
--   <C-]> → same as gf (fallback to tags)
--   gl  → list all links in a picker
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

-- ── Pattern library ───────────────────────────────────────────────────────────

-- Ordered list: each entry is { pattern, type }
-- `type` is "url" | "file"
-- Patterns use plain Lua regexes (no PCRE).
local PATTERNS = {
  -- URLs
  { pat = "https?://[^%s%]%)>\"']+", kind = "url" },
  { pat = "file://[^%s%]%)>\"']+", kind = "url" },
  -- file:line or file:line:col  (common compiler/linter output)
  -- e.g.  src/main.lua:42:5   or  ./lib/foo.py:100
  { pat = "[%./][^%s:\"'%(%)%[%]]+%.[%a]+:%d+", kind = "file" },
  { pat = "[%a_][%w%./%-_]*%.[%a][%a%d]+:%d+", kind = "file" },
  -- Rust-style:  --> src/main.rs:12:34
  { pat = "%->%s+[^%s:\"']+:%d+", kind = "file" },
  -- Python traceback:  File "foo.py", line 42
  { pat = 'File "[^"]+", line %d+', kind = "file_py" },
  -- Go:  /abs/path/to/file.go:42 +0x...
  { pat = "/[^%s:%(%)\"']+%.go:%d+", kind = "file" },
  -- Node / JS:  at Object. (/path/to/file.js:10:5)
  { pat = "%(([^%)]+%.%a+:%d+)%)", kind = "file" },
}

-- ── Parsing helpers ────────────────────────────────────────────────────────────

--- Parse "path:line[:col]" → { path, line, col } or nil.
local function parse_file_loc(s)
  -- Strip leading --> or whitespace
  s = s:match("^%-*>?%s*(.+)") or s
  -- Strip surrounding parens
  s = s:match("^%((.+)%)$") or s

  -- path:line:col
  local path, line, col = s:match("^(.+):(%d+):(%d+)$")
  if path then
    return { path = path, line = tonumber(line), col = tonumber(col) }
  end

  -- path:line
  path, line = s:match("^(.+):(%d+)$")
  if path then
    return { path = path, line = tonumber(line), col = 0 }
  end

  return nil
end

--- Parse Python-style  File "foo.py", line 42  → { path, line }.
local function parse_python_file(s)
  local path, line = s:match('^File "([^"]+)", line (%d+)')
  if path then
    return { path = path, line = tonumber(line), col = 0 }
  end
  return nil
end

--- Resolve a possibly-relative path against Neovim's cwd.
local function resolve_path(raw_path)
  if raw_path:sub(1, 1) == "/" then
    return raw_path
  end
  return vim.fn.getcwd() .. "/" .. raw_path
end

-- ── Extmark highlighting ───────────────────────────────────────────────────────

local URL_HL = "TermManagerLinkURL"
local FILE_HL = "TermManagerLinkFile"

local function setup_hl()
  vim.api.nvim_set_hl(0, URL_HL, { link = "Underlined", default = true })
  vim.api.nvim_set_hl(0, FILE_HL, { link = "DiagnosticInfo", default = true })
end
setup_hl()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("TermManagerLinksHL", { clear = true }),
  callback = setup_hl,
})

--- Scan `lines` (list of strings) and return a list of match tables:
---   { lnum, col_s, col_e, kind, raw, parsed }
local function scan_lines(lines)
  local matches = {}
  for lnum, text in ipairs(lines) do
    for _, spec in ipairs(PATTERNS) do
      local s = 1
      while s <= #text do
        local ms, me = text:find(spec.pat, s)
        if not ms then
          break
        end
        local raw = text:sub(ms, me)
        local parsed = nil
        if spec.kind == "url" then
          parsed = { url = raw }
        elseif spec.kind == "file_py" then
          parsed = parse_python_file(raw)
        else
          parsed = parse_file_loc(raw)
        end
        if parsed then
          matches[#matches + 1] = {
            lnum = lnum,
            col_s = ms - 1, -- 0-based
            col_e = me,
            kind = spec.kind,
            raw = raw,
            parsed = parsed,
          }
        end
        s = me + 1
      end
    end
  end
  return matches
end

-- ── Per-buffer highlighting ────────────────────────────────────────────────────

--- Re-scan the last N lines of `buf` and refresh extmark highlights.
local SCAN_LINES = 300 -- how many trailing lines to scan

function M.refresh_highlights(buf)
  if not utils.buf_ok(buf) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local start_line = math.max(0, line_count - SCAN_LINES)
  local raw_lines = vim.api.nvim_buf_get_lines(buf, start_line, -1, false)

  -- Clear old link marks
  vim.api.nvim_buf_clear_namespace(buf, state.link_ns, start_line, -1)

  local matches = scan_lines(raw_lines)
  for _, m in ipairs(matches) do
    local abs_lnum = start_line + m.lnum - 1 -- 0-based absolute line
    local hl = m.kind == "url" and URL_HL or FILE_HL
    pcall(vim.api.nvim_buf_set_extmark, buf, state.link_ns, abs_lnum, m.col_s, {
      end_col = m.col_e,
      hl_group = hl,
      priority = 50,
    })
  end
end

-- ── Navigation ────────────────────────────────────────────────────────────────

--- Find the link closest to (or at) the current cursor position in `buf`.
--- Returns the match table or nil.
local function link_at_cursor(buf)
  if not utils.buf_ok(buf) then
    return nil
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local lnum0 = cur[1] - 1 -- 0-based
  local col0 = cur[2]

  local line_count = vim.api.nvim_buf_line_count(buf)
  local start_line = math.max(0, line_count - SCAN_LINES)

  -- Only scan the visible window range ± a few lines for speed.
  local range_s = math.max(start_line, lnum0 - 2)
  local range_e = math.min(line_count, lnum0 + 3)
  local raw_lines = vim.api.nvim_buf_get_lines(buf, range_s, range_e, false)

  local matches = scan_lines(raw_lines)
  for _, m in ipairs(matches) do
    local abs = range_s + m.lnum - 1
    if abs == lnum0 and m.col_s <= col0 and col0 < m.col_e then
      return m
    end
  end
  -- Broaden: any match on the same line
  for _, m in ipairs(matches) do
    local abs = range_s + m.lnum - 1
    if abs == lnum0 then
      return m
    end
  end
  return nil
end

--- Open the URL or file:line reference under the cursor.
function M.open_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local m = link_at_cursor(buf)
  if not m then
    vim.notify("TermManager: no link under cursor", vim.log.levels.INFO)
    return
  end

  if m.kind == "url" then
    -- Open URL using Neovim's built-in opener (or xdg-open / open).
    local url = m.parsed.url
    if vim.ui and vim.ui.open then
      vim.ui.open(url)
    else
      local cmd = vim.fn.has("mac") == 1 and "open" or "xdg-open"
      vim.fn.jobstart({ cmd, url }, { detach = true })
    end
    vim.notify("TermManager: opening " .. url, vim.log.levels.INFO)
  else
    -- File + line reference → jump to that file in Neovim.
    local loc = m.parsed
    if not loc then
      return
    end
    local path = resolve_path(loc.path)

    -- Leave the terminal, open in the editor area.
    vim.cmd("wincmd k") -- move up to editor windows

    -- Find an existing normal (non-terminal) window or use the first one.
    local target_win = nil
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local bt = vim.api.nvim_get_option_value("buftype", { win = w })
      if bt == "" then
        target_win = w
        break
      end
    end

    if target_win then
      vim.api.nvim_set_current_win(target_win)
    end

    -- Edit the file and jump to line.
    if vim.fn.filereadable(path) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      if loc.line and loc.line > 0 then
        vim.api.nvim_win_set_cursor(0, { loc.line, math.max(0, (loc.col or 1) - 1) })
        vim.cmd("normal! zv") -- open folds
        vim.cmd("normal! zz") -- centre view
      end
    else
      vim.notify("TermManager: file not found: " .. path, vim.log.levels.WARN)
    end
  end
end

--- List all links in the current terminal buffer in a picker.
function M.list_links()
  local buf = vim.api.nvim_get_current_buf()
  if not utils.buf_ok(buf) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  local start_line = math.max(0, line_count - SCAN_LINES)
  local raw_lines = vim.api.nvim_buf_get_lines(buf, start_line, -1, false)
  local matches = scan_lines(raw_lines)

  if #matches == 0 then
    vim.notify("TermManager: no links found in visible output", vim.log.levels.INFO)
    return
  end

  -- Deduplicate by raw text.
  local seen = {}
  local unique = {}
  for _, m in ipairs(matches) do
    if not seen[m.raw] then
      seen[m.raw] = true
      unique[#unique + 1] = m
    end
  end

  local items = vim.tbl_map(function(m)
    local icon = m.kind == "url" and "🌐" or "📄"
    return icon .. "  " .. m.raw
  end, unique)

  vim.ui.select(items, { prompt = "Links:" }, function(_, idx)
    if not idx then
      return
    end
    local m = unique[idx]
    -- Position cursor and delegate to open_at_cursor logic
    local abs_lnum = start_line + m.lnum -- 1-based
    pcall(vim.api.nvim_win_set_cursor, 0, { abs_lnum, m.col_s })
    vim.schedule(M.open_at_cursor)
  end)
end

-- ── Autocmd setup ─────────────────────────────────────────────────────────────

--- Attach link-detection autocmds and keymaps to a terminal buffer.
function M.attach(buf)
  if not utils.buf_ok(buf) then
    return
  end

  local aug = vim.api.nvim_create_augroup("TermManagerLinks_" .. buf, { clear = true })

  -- Refresh highlights whenever the terminal output changes.
  vim.api.nvim_create_autocmd({ "TextChanged", "BufWinEnter" }, {
    group = aug,
    buffer = buf,
    callback = function()
      vim.schedule(function()
        M.refresh_highlights(buf)
      end)
    end,
  })

  -- Initial scan.
  vim.schedule(function()
    M.refresh_highlights(buf)
  end)

  -- Keymaps (buffer-local, normal mode).
  local ko = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "gx", M.open_at_cursor, vim.tbl_extend("force", ko, { desc = "open link/file" }))
  vim.keymap.set("n", "gf", M.open_at_cursor, vim.tbl_extend("force", ko, { desc = "go to file:line" }))
  vim.keymap.set("n", "gl", M.list_links, vim.tbl_extend("force", ko, { desc = "list links" }))
end

return M
