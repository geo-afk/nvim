-- tabline/session.lua
-- Per-directory buffer persistence.
--
-- FEATURE OVERVIEW
-- ────────────────
-- • On exit  → collect every listed, real-file buffer and write a small JSON
--              file keyed to the current working directory.
-- • On start → if the CWD has a saved session AND Neovim was opened with no
--              file arguments, re-open those buffers and switch to the last
--              active one.
--
-- SESSION FILE FORMAT  (stored in {data_dir}/{sanitised-cwd}.json)
-- ────────────────────
-- {
--   "version": 1,
--   "cwd":      "/home/user/myproject",
--   "saved_at": 1700000000,
--   "active":   "/home/user/myproject/src/init.lua",
--   "buffers":  [
--     "/home/user/myproject/src/init.lua",
--     "/home/user/myproject/README.md"
--   ]
-- }
--
-- FILES ARE NEVER MODIFIED IN PLACE — they are written atomically via a
-- temporary file + rename so a crash during write never corrupts the session.
--
-- RELIABILITY NOTES
-- ─────────────────
-- • Both VimLeavePre (normal :quit) AND UILeave (terminal window killed) are
--   listened to.  A "already saved" guard prevents the double-write.
--   Research source: https://github.com/stevearc/resession.nvim/issues/49
-- • vim.json.encode/decode are used (available since Neovim 0.6, stable on
--   0.9+).  Both calls are wrapped in pcall so a corrupted file never crashes.
-- • Non-existent files are silently skipped on restore so stale sessions
--   (after renaming/deleting files) are handled gracefully.
-- • Headless mode (no UI) is detected and skipped.

local M = {}
local _config = nil   -- set by M.setup(), the persist sub-table

-- ─── internal state ───────────────────────────────────────────────────────

local _saved_this_session = false  -- dedup guard for VimLeavePre + UILeave

-- ─── path helpers ─────────────────────────────────────────────────────────

--- Sanitise a directory path into a safe filename component.
--- Strategy: replace every run of non-alphanumeric characters with a single
--- "+" so the result is readable and debuggable while still being unique.
--- A SHA256-based name would be collision-proof but opaque; this trades a
--- tiny theoretical collision risk (two CWDs with identical sanitised forms,
--- which cannot happen on a normal filesystem) for human readability.
---
--- Examples:
---   /home/alice/my-project  →  home+alice+my-project
---   C:\Users\alice\proj     →  C+Users+alice+proj
---   /tmp/test dir           →  tmp+test+dir
---@param cwd string
---@return string  safe filename (no extension)
local function sanitise(cwd)
  -- Normalise path separators on Windows
  local p = cwd:gsub("\\", "/")
  -- Strip leading / or drive letter (C:/) so the file doesn't start with "+"
  p = p:gsub("^%a:/", ""):gsub("^/", "")
  -- Replace runs of non-alnum characters with "+"
  p = p:gsub("[^%w]+", "+")
  -- Strip trailing "+"
  p = p:gsub("%+$", "")
  return p ~= "" and p or "root"
end

--- Return the absolute path to the session JSON file for `cwd`.
---@param cwd string
---@return string
local function session_path(cwd)
  return _config.data_dir .. "/" .. sanitise(cwd) .. ".json"
end

-- ─── guard helpers ────────────────────────────────────────────────────────

--- Return true if the CWD is in the skip_dirs list.
---@param cwd string
---@return boolean
local function is_skipped_dir(cwd)
  local abs_cwd = vim.fn.fnamemodify(cwd, ":p"):gsub("[/\\]$", "")
  for _, d in ipairs(_config.skip_dirs or {}) do
    local abs_d = vim.fn.fnamemodify(d, ":p"):gsub("[/\\]$", "")
    if abs_cwd == abs_d then return true end
  end
  return false
end

--- Return true if a buffer should be included in the saved list.
---@param b integer  bufnr
---@return boolean
local function is_saveable(b)
  if not vim.api.nvim_buf_is_valid(b) then return false end
  if vim.fn.buflisted(b) ~= 1          then return false end

  local bt = vim.bo[b].buftype
  -- Only plain file buffers (empty buftype) are saved.
  -- Excludes: terminal, help, quickfix, nofile, prompt, …
  if bt ~= "" then return false end

  local ft = vim.bo[b].filetype
  for _, skip in ipairs(_config.skip_filetypes or {}) do
    if ft == skip then return false end
  end

  local name = vim.api.nvim_buf_get_name(b)
  -- Must have a real path
  if name == "" then return false end

  return true
end

-- ─── disk I/O ─────────────────────────────────────────────────────────────

--- Ensure a directory exists, creating it recursively if needed.
--- Returns true on success, false + error string on failure.
---@param dir string
---@return boolean, string?
local function mkdir_p(dir)
  if vim.fn.isdirectory(dir) == 1 then return true end
  local ok, err = pcall(vim.fn.mkdir, dir, "p")
  if not ok then return false, tostring(err) end
  if vim.fn.isdirectory(dir) ~= 1 then
    return false, "mkdir failed silently for " .. dir
  end
  return true
end

--- Write `content` to `path` atomically via a temp file + rename.
--- Atomic write prevents a crash leaving a half-written (corrupt) JSON file.
---@param path    string
---@param content string
---@return boolean ok, string? err
local function atomic_write(path, content)
  local tmp = path .. ".tmp"

  local fh, open_err = io.open(tmp, "w")
  if not fh then
    return false, "cannot open tmp file: " .. tostring(open_err)
  end

  local ok, write_err = fh:write(content)
  fh:close()

  if not ok then
    os.remove(tmp)
    return false, "write failed: " .. tostring(write_err)
  end

  -- os.rename is atomic on POSIX; on Windows it may fail if destination
  -- exists — try to remove it first.
  local ren_ok, ren_err = os.rename(tmp, path)
  if not ren_ok then
    -- Windows fallback
    os.remove(path)
    ren_ok, ren_err = os.rename(tmp, path)
  end

  if not ren_ok then
    os.remove(tmp)
    return false, "rename failed: " .. tostring(ren_err)
  end

  return true
end

--- Read and JSON-decode a session file.
--- Returns the decoded table, or nil + error string.
---@param path string
---@return table|nil, string?
local function read_session(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil, "file not found: " .. path
  end

  local fh, open_err = io.open(path, "r")
  if not fh then
    return nil, "cannot open: " .. tostring(open_err)
  end

  local raw = fh:read("*a")
  fh:close()

  if not raw or raw == "" then
    return nil, "empty file"
  end

  local ok, data = pcall(vim.json.decode, raw)
  if not ok then
    return nil, "JSON parse error: " .. tostring(data)
  end

  if type(data) ~= "table" then
    return nil, "unexpected JSON root type"
  end

  return data
end

-- ─── public API ───────────────────────────────────────────────────────────

function M.setup(persist_config)
  _config = persist_config
end

--- Collect saveable buffers and write a session file for `cwd`.
---@param cwd     string   current working directory
---@param silent  boolean  suppress user-facing notifications on success
---@return boolean ok
function M.save(cwd, silent)
  if not _config or not _config.enabled then return false end
  if is_skipped_dir(cwd) then return false end

  -- Collect buffer paths in tabline order (falls back to nvim_list_bufs order)
  local bufs_mod = require("custom.tabline.buffers")
  local ordered  = bufs_mod.get_buffers()

  local paths = {}
  for _, b in ipairs(ordered) do
    if is_saveable(b) then
      paths[#paths + 1] = vim.api.nvim_buf_get_name(b)
    end
  end

  -- Nothing meaningful to save → remove any stale session so we don't
  -- accidentally restore a decades-old session after emptying the project.
  if #paths == 0 then
    local p = session_path(cwd)
    if vim.fn.filereadable(p) == 1 then os.remove(p) end
    return true
  end

  -- Determine the active buffer path (may not be in the saveable list
  -- if it's a terminal/scratch, in which case we store nil / omit it).
  local cur = vim.api.nvim_get_current_buf()
  local active_path = nil
  if is_saveable(cur) then
    active_path = vim.api.nvim_buf_get_name(cur)
  else
    -- Fall back to the first saveable buffer as the "active" entry
    active_path = paths[1]
  end

  local session = {
    version  = 1,
    cwd      = cwd,
    saved_at = os.time(),
    active   = active_path,
    buffers  = paths,
  }

  -- Encode — pcall because vim.json.encode can fail on invalid UTF-8 paths
  local enc_ok, json_or_err = pcall(vim.json.encode, session)
  if not enc_ok then
    vim.notify("tabline: session encode failed: " .. tostring(json_or_err),
               vim.log.levels.WARN)
    return false
  end

  -- Ensure the data directory exists
  local dir_ok, dir_err = mkdir_p(_config.data_dir)
  if not dir_ok then
    vim.notify("tabline: cannot create session dir: " .. tostring(dir_err),
               vim.log.levels.WARN)
    return false
  end

  local path = session_path(cwd)
  local w_ok, w_err = atomic_write(path, json_or_err)
  if not w_ok then
    vim.notify("tabline: session write failed: " .. tostring(w_err),
               vim.log.levels.WARN)
    return false
  end

  if not silent then
    vim.notify("tabline: session saved (" .. #paths .. " buffers)", vim.log.levels.INFO)
  end

  return true
end

--- Re-open buffers from a saved session for `cwd`.
--- Safe to call multiple times — already-open buffers are skipped.
---@param cwd    string
---@param notify boolean  show a message after restoring
---@return boolean ok
function M.restore(cwd, notify)
  if not _config or not _config.enabled then return false end
  if is_skipped_dir(cwd) then return false end

  local path = session_path(cwd)
  local data, err = read_session(path)

  if not data then
    -- No session → not an error, just nothing to do
    return false
  end

  -- Version check (future-proofing)
  if data.version ~= 1 then
    vim.notify("tabline: unknown session version " .. tostring(data.version)
               .. " — skipping restore", vim.log.levels.WARN)
    return false
  end

  -- Validate the CWD matches (guards against session files being moved)
  if data.cwd and vim.fn.fnamemodify(data.cwd, ":p") ~= vim.fn.fnamemodify(cwd, ":p") then
    vim.notify("tabline: session cwd mismatch, skipping restore", vim.log.levels.WARN)
    return false
  end

  local buffers = data.buffers
  if type(buffers) ~= "table" or #buffers == 0 then
    return false
  end

  local restored  = 0
  local first_buf = nil   -- first successfully restored buffer

  for _, fpath in ipairs(buffers) do
    -- Only restore files that actually exist on disk
    if type(fpath) == "string"
       and fpath ~= ""
       and vim.fn.filereadable(fpath) == 1 then

      -- badd adds the buffer without switching to it or triggering BufEnter,
      -- which means we can load all buffers silently then switch once at the end.
      vim.cmd.badd({ args = { fpath }, mods = { silent = true } })

      local bufnr = vim.fn.bufnr(fpath)
      if bufnr ~= -1 then
        restored  = restored + 1
        if first_buf == nil then first_buf = bufnr end
      end
    end
  end

  if restored == 0 then return false end

  -- Switch to the saved active buffer (or the first restored one)
  local active_path = data.active
  local target_buf  = nil

  if type(active_path) == "string" and active_path ~= "" then
    local bn = vim.fn.bufnr(active_path)
    if bn ~= -1 and vim.api.nvim_buf_is_valid(bn) then
      target_buf = bn
    end
  end

  target_buf = target_buf or first_buf

  if target_buf then
    -- pcall: switching can fail if the buffer was wiped between badd and here
    local sw_ok, sw_err = pcall(vim.api.nvim_set_current_buf, target_buf)
    if not sw_ok then
      vim.notify("tabline: could not switch to restored buffer: " .. tostring(sw_err),
                 vim.log.levels.WARN)
    end
  end

  -- Wipe every leftover blank [No Name] buffer.
  --
  -- When Neovim starts it creates one unlisted-or-listed empty buffer
  -- (bufnr 1, name=""). After badd() loads real files that buffer is still
  -- in the buffer list and appears as a [No Name] tab.  The same issue
  -- occurs when :TablineSessionRestore is called manually on a blank buffer.
  --
  -- Criteria for "safe to wipe":
  --   • name == ""          (genuinely unnamed — not a file with no name set yet)
  --   • buftype == ""       (plain buffer, not terminal/help/etc.)
  --   • NOT modified        (never discard unsaved work)
  --   • NOT the target_buf  (in the unlikely case target_buf itself is blank)
  --
  -- We use force=false so Neovim will refuse to delete a modified buffer
  -- even if our modified-flag check has a race condition.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b)
       and b ~= target_buf
       and vim.api.nvim_buf_get_name(b) == ""
       and vim.bo[b].buftype == ""
       and not vim.bo[b].modified then
      pcall(vim.api.nvim_buf_delete, b, { force = false })
    end
  end

  if notify then
    vim.notify("tabline: restored " .. restored .. " buffer(s) for " .. cwd,
               vim.log.levels.INFO)
  end

  return true
end

--- Return the path of the session file for `cwd`, or nil if none exists.
---@param cwd string
---@return string|nil
function M.session_file(cwd)
  if not _config then return nil end
  local p = session_path(cwd)
  return vim.fn.filereadable(p) == 1 and p or nil
end

--- Called by both VimLeavePre and UILeave autocmds.
--- A module-level flag prevents double-writing if both events fire.
---@param cwd string
function M.save_on_exit_handler(cwd)
  if _saved_this_session then return end
  _saved_this_session = true
  -- Save silently on exit — no notification needed, it would flash then disappear.
  M.save(cwd, true)
end

--- Delete the session file for `cwd`.
---@param cwd string
---@return boolean ok
function M.delete(cwd)
  if not _config then return false end
  local p = session_path(cwd)
  if vim.fn.filereadable(p) == 1 then
    local ok = os.remove(p)
    return ok ~= nil
  end
  return false
end

--- Return a list of all saved session records (each with .cwd and .path).
---@return {cwd: string, path: string, saved_at: integer|nil, count: integer|nil}[]
function M.list()
  if not _config then return {} end
  if vim.fn.isdirectory(_config.data_dir) ~= 1 then return {} end

  local results = {}
  local handle = vim.loop.fs_scandir(_config.data_dir)
  if not handle then return {} end

  while true do
    local name, ftype = vim.loop.fs_scandir_next(handle)
    if not name then break end

    if ftype == "file" and name:match("%.json$") then
      local full = _config.data_dir .. "/" .. name
      local data, _ = read_session(full)
      if data then
        results[#results + 1] = {
          cwd      = data.cwd or "?",
          path     = full,
          saved_at = data.saved_at,
          count    = type(data.buffers) == "table" and #data.buffers or 0,
        }
      end
    end
  end

  -- Sort by most recently saved first
  table.sort(results, function(a, b)
    return (a.saved_at or 0) > (b.saved_at or 0)
  end)

  return results
end

return M
