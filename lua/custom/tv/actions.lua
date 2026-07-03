-- =============================================================================
--  custom/tv/actions.lua  ·  Action handlers for television channel selections
-- =============================================================================
--
--  Each action is a function:  fun(entries: string[])
--  `entries` is always a list of selected strings from tv.
--
--  Design intent:
--  - Actions are pure functions with no hidden state.
--  - Actions are composable and independently testable.
--  - Channel-specific parsing lives here, not in channels.lua.
-- =============================================================================

local M = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

--- Parse a `text`-channel entry of the form "path/to/file:line:col:content"
--- Returns { path, line, col } or nil on failure.
---@param entry string
---@return { path: string, line: integer, col: integer }?
local function parse_text_entry(entry)
  local path, line, col = entry:match("^(.+):(%d+):(%d+):")
  if path then
    return { path = path, line = tonumber(line), col = tonumber(col) }
  end
  -- Fallback: path:line (no col)
  path, line = entry:match("^(.+):(%d+)$")
  if path then
    return { path = path, line = tonumber(line), col = 1 }
  end
  return nil
end

--- Resolve a path to an absolute path if it exists relative to cwd.
---@param path string
---@return string
local function resolve_path(path)
  if vim.fn.filereadable(path) == 1 then
    return path
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  return abs
end

--- Open a file in the current window, creating it if necessary.
---@param path string
---@param line integer?
---@param col integer?
local function open_file(path, line, col)
  path = resolve_path(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  if line and line > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { line, math.max(0, (col or 1) - 1) })
    vim.cmd("normal! zv")
  end
end

-- ─── File actions ─────────────────────────────────────────────────────────────

--- Open each entry as a file buffer in the current window.
---@param entries string[]
function M.open_as_files(entries)
  for _, entry in ipairs(entries) do
    local path = vim.trim(entry)
    if path ~= "" then
      open_file(path)
    end
  end
end

--- Open first entry and jump to the embedded line:col (text channel format).
---@param entries string[]
function M.open_at_line(entries)
  local entry = entries[1]
  if not entry then
    return
  end
  local parsed = parse_text_entry(vim.trim(entry))
  if parsed then
    open_file(parsed.path, parsed.line, parsed.col)
  else
    open_file(vim.trim(entry))
  end
end

--- Open first entry in a horizontal split.
---@param entries string[]
function M.open_in_split(entries)
  local entry = vim.trim(entries[1] or "")
  if entry == "" then
    return
  end
  local parsed = parse_text_entry(entry)
  local path = parsed and parsed.path or entry
  vim.cmd("split " .. vim.fn.fnameescape(resolve_path(path)))
  if parsed and parsed.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { parsed.line, math.max(0, (parsed.col or 1) - 1) })
    vim.cmd("normal! zv")
  end
end

--- Open first entry in a vertical split.
---@param entries string[]
function M.open_in_vsplit(entries)
  local entry = vim.trim(entries[1] or "")
  if entry == "" then
    return
  end
  local parsed = parse_text_entry(entry)
  local path = parsed and parsed.path or entry
  vim.cmd("vsplit " .. vim.fn.fnameescape(resolve_path(path)))
  if parsed and parsed.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { parsed.line, math.max(0, (parsed.col or 1) - 1) })
    vim.cmd("normal! zv")
  end
end

--- Populate the quickfix list with all entries.
--- Supports both plain file paths and text-channel "file:line:col:content" entries.
---@param entries string[]
function M.send_to_quickfix(entries)
  local qf = {}
  for _, entry in ipairs(entries) do
    entry = vim.trim(entry)
    if entry ~= "" then
      local parsed = parse_text_entry(entry)
      if parsed then
        -- Extract trailing content after line:col: for the text
        local text = entry:match("^.+:%d+:%d+:(.*)$") or ""
        qf[#qf + 1] = {
          filename = resolve_path(parsed.path),
          lnum = parsed.line,
          col = parsed.col,
          text = text,
        }
      else
        qf[#qf + 1] = { filename = resolve_path(entry), lnum = 1, col = 1, text = "" }
      end
    end
  end
  if #qf > 0 then
    vim.fn.setqflist(qf, "r")
    vim.cmd("copen")
  end
end

-- ─── Text insertion actions ───────────────────────────────────────────────────

--- Insert the first entry at the current cursor position.
---@param entries string[]
function M.insert_at_cursor(entries)
  local text = vim.trim(entries[1] or "")
  if text == "" then
    return
  end
  -- For env channel, strip to just the value part ("KEY=value" → value)
  local val = text:match("^[^=]+=(.+)$")
  local to_insert = val or text
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local new_line = line:sub(1, col) .. to_insert .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  pcall(vim.api.nvim_win_set_cursor, 0, { row, col + #to_insert })
end

--- Insert each entry on a new line below the cursor.
---@param entries string[]
function M.insert_on_new_line(entries)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = {}
  for _, entry in ipairs(entries) do
    local text = vim.trim(entry)
    if text ~= "" then
      lines[#lines + 1] = text
    end
  end
  if #lines > 0 then
    vim.api.nvim_buf_set_lines(0, row, row, false, lines)
    pcall(vim.api.nvim_win_set_cursor, 0, { row + #lines, 0 })
  end
end

--- Copy all entries to the system clipboard (+ register).
---@param entries string[]
function M.copy_to_clipboard(entries)
  local text = table.concat(entries, "\n")
  vim.fn.setreg("+", text)
  vim.fn.setreg("*", text)
  vim.notify(
    string.format("[tv] Copied %d %s to clipboard", #entries, #entries == 1 and "entry" or "entries"),
    vim.log.levels.INFO
  )
end

-- ─── Git actions ──────────────────────────────────────────────────────────────

--- Checkout the selected branch (git-branch channel).
---@param entries string[]
function M.git_checkout(entries)
  local branch = vim.trim(entries[1] or ""):gsub("^%*%s*", ""):gsub("^remotes/[^/]+/", "")
  if branch == "" then
    return
  end
  vim.system({ "git", "checkout", branch }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("[tv] Switched to branch: " .. branch, vim.log.levels.INFO)
      else
        vim.notify("[tv] git checkout failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
      end
    end)
  end)
end

--- Show the selected commit diff in a scratch buffer (git-log channel).
--- Entry format is typically: "hash  commit message  (date)"
---@param entries string[]
function M.git_show_commit(entries)
  local entry = vim.trim(entries[1] or "")
  -- Extract the first word as the commit hash
  local hash = entry:match("^(%S+)")
  if not hash then
    return
  end
  vim.system({ "git", "show", hash }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("[tv] git show failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local lines = vim.split(result.stdout or "", "\n", { plain = true })
      -- Remove trailing empty line from split
      if lines[#lines] == "" then
        lines[#lines] = nil
      end
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
      vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
      vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
      vim.api.nvim_set_option_value("filetype", "git", { buf = buf })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      vim.cmd("split")
      vim.api.nvim_win_set_buf(0, buf)
      vim.cmd("normal! gg")
    end)
  end)
end

--- Copy the commit hash (first word) to the clipboard (git-log/reflog channel).
---@param entries string[]
function M.git_copy_hash(entries)
  local entry = vim.trim(entries[1] or "")
  local hash = entry:match("^(%S+)") or entry
  vim.fn.setreg("+", hash)
  vim.fn.setreg("*", hash)
  vim.notify("[tv] Copied hash: " .. hash, vim.log.levels.INFO)
end

--- Re-run the selected command from shell history in a terminal split.
--- Works for both pwsh-history and nu-history channels.
---@param entries string[]
function M.run_from_history(entries)
  local cmd = vim.trim(entries[1] or "")
  if cmd == "" then
    return
  end
  -- Use the existing float_term infrastructure if available.
  local ok, term = pcall(require, "custom.float_term.term")
  if ok then
    term.create_terminal(cmd, { title = " " .. cmd:sub(1, 40) .. " " })
  else
    -- Fallback: open a split terminal running the command.
    vim.cmd("split | terminal " .. cmd)
  end
end

--- Open the selected git repository in a new tab (cd + explorer).
---@param entries string[]
function M.open_git_repo(entries)
  local path = vim.trim(entries[1] or "")
  if path == "" then
    return
  end
  -- Strip trailing ".git" segment if included
  path = path:gsub("[/\\]%.git$", "")
  vim.cmd("tabnew")
  vim.cmd("tcd " .. vim.fn.fnameescape(path))
  vim.notify("[tv] Opened repo: " .. path, vim.log.levels.INFO)
end

--- Execute a raw shell command built from a template.
--- `template` may contain `{}` which is replaced by the selected entry.
---@param template string
---@return fun(entries: string[])
function M.execute_shell_command(template)
  return function(entries)
    local entry = vim.trim(entries[1] or "")
    if entry == "" then
      return
    end
    local cmd = template:gsub("{}", vim.fn.shellescape(entry):gsub("^'", ""):gsub("'$", ""))
    local ok, term = pcall(require, "custom.float_term.term")
    if ok then
      term.create_terminal(cmd, { title = " " .. cmd:sub(1, 50) })
    else
      vim.cmd("!" .. cmd)
    end
  end
end

return M
