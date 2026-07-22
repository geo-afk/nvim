-- custom/explorer/init.lua
-- Usage: require("custom.explorer").setup()

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local render = require("custom.explorer.render")
local git = require("custom.explorer.git")
local win = require("custom.explorer.win")
local search = require("custom.explorer.search")
local search_ui = require("custom.explorer.search_ui")
local icons = require("custom.explorer.icons")
local store = require("custom.explorer.project_store")
local diag = require("custom.explorer.diagnostics")
local nvim_utils = require("utils.nvim")

local api = vim.api
local fn = vim.fn
local M = {}
local did_setup = false

local ROOT_MARKERS = {
  ".git",
  ".hg",
  ".svn",
  "package.json",
  "go.mod",
  "Cargo.toml",
  "pyproject.toml",
  "requirements.txt",
  "composer.json",
  "Makefile",
  "tsconfig.json",
  "jsconfig.json",
  "Gemfile",
  "rebar.config",
}

local function find_project_root(path)
  path = path or api.nvim_buf_get_name(0)
  if path == "" or path:match("^explorer://") then
    path = fn.getcwd()
  end
  path = tree.norm(fn.fnamemodify(path, ":p"))

  -- If it's a file, start from its directory
  if fn.isdirectory(path) == 0 then
    path = tree.parent(path)
  end

  local root = vim.fs.root(path, ROOT_MARKERS)
  if root then
    -- Safety check: don't default to the home directory if it happens to have a marker
    local home = tree.norm(fn.expand("~"))
    if root == home and path ~= home then
      -- If the only marker found is at HOME, and we are not in HOME,
      -- just use the immediate directory instead of the entire user folder.
      return path
    end
    return root
  end

  return path
end

local function is_regular_edit_window(winid)
  if not (winid and api.nvim_win_is_valid(winid)) then
    return false
  end
  if S.win and winid == S.win then
    return false
  end
  if api.nvim_win_get_config(winid).relative ~= "" then
    return false
  end
  local buf = api.nvim_win_get_buf(winid)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  local ft = vim.bo[buf].filetype
  if ft == "explorer" or ft == "explorer_projects" or ft == "explorer_prompt" or ft == "explorer_popup" then
    return false
  end
  if vim.wo[winid].previewwindow then
    return false
  end
  return true
end

-- ── File watcher ──────────────────────────────────────────────────────────
-- Debounce set to 500ms to prevent visual flicker from rapid file-system events.

local _watcher, _debounce

local function watch_start()
  if _watcher then
    pcall(function()
      _watcher:stop()
    end)
    pcall(function()
      _watcher:close()
    end)
    _watcher = nil
  end
  local uv = vim.uv
  local w = uv.new_fs_event()
  if not w then
    return
  end
  local ok = w:start(
    S.root,
    { recursive = true },
    vim.schedule_wrap(function(err)
      if err then
        return
      end
      S.scan_cache = {}
      if S.search_active then
        return
      end
      if _debounce then
        _debounce:stop()
      end
      _debounce = vim.defer_fn(function()
        _debounce = nil
        render.render()
        git.fetch()
      end, 500)
    end)
  )
  if ok == 0 or ok == nil then
    _watcher = w
  else
    pcall(function()
      w:close()
    end)
  end
end

local function watch_stop()
  if _debounce then
    pcall(function()
      _debounce:stop()
    end)
    _debounce = nil
  end
  if _watcher then
    pcall(function()
      _watcher:stop()
    end)
    pcall(function()
      _watcher:close()
    end)
    _watcher = nil
  end
end

local function list_to_open_dirs(paths)
  local open_dirs = {}
  if type(paths) ~= "table" then
    return open_dirs
  end
  for _, path in ipairs(paths) do
    if type(path) == "string" and path ~= "" then
      open_dirs[tree.norm(fn.fnamemodify(path, ":p"))] = true
    end
  end
  return open_dirs
end

local function open_dirs_to_list()
  local paths = {}
  for path, is_open in pairs(S.open_dirs or {}) do
    if is_open then
      paths[#paths + 1] = tree.norm(fn.fnamemodify(path, ":p"))
    end
  end
  table.sort(paths)
  return paths
end

local function find_existing_window()
  for _, winid in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(winid) and api.nvim_win_get_config(winid).relative == "" then
      local buf = api.nvim_win_get_buf(winid)
      if buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "explorer" then
        return winid, buf
      end
    end
  end
end

-- ── reveal ────────────────────────────────────────────────────────────────
--
-- Move the explorer cursor to the line corresponding to `path`.
--
-- Design:
--   1. If the file is already visible in S.items (parents open, no filter
--      hiding it), just move the cursor directly — no rebuild needed.
--      This is the common case for follow_file (BufEnter) and is O(n) only.
--
--   2. If the file is NOT in S.items (parent dirs collapsed, or first open),
--      expand all ancestor dirs, register the path as S._reveal_target, and
--      call render.render().  The build callback in render.lua will call
--      render._reveal_cursor() once the tree is repopulated.
--
--   render.render() is debounced with a _scheduled flag, so even if a file-
--   watcher and a reveal both fire within the same event loop tick, they
--   collapse into one tree build.  The reveal target is consumed after that
--   single build completes.

function M.reveal(path)
  if not path or path == "" then
    return
  end
  path = tree.norm(fn.fnamemodify(path, ":p"))
  if not vim.startswith(path, S.root) then
    return
  end
  if S.search_active then
    return
  end

  -- ── Fast path: file is already in the rendered tree ───────────────────
  -- Scan S.items first.  If found, just reposition the cursor and center
  -- the viewport — no I/O, no rebuild.
  if S.win and api.nvim_win_is_valid(S.win) then
    for i, it in ipairs(S.items) do
      if it.path == path then
        local cur_row = api.nvim_win_get_cursor(S.win)[1]
        local target_line = search_ui.line_for_item(i)
        if cur_row == target_line then
          return
        end -- already there, nothing to do
        pcall(api.nvim_win_set_cursor, S.win, { target_line, 0 })
        pcall(api.nvim_win_call, S.win, function()
          vim.cmd("normal! zz")
        end)
        return
      end
    end
  end

  -- ── Slow path: tree needs to be rebuilt ───────────────────────────────
  -- Expand every ancestor directory so the file becomes visible after build.
  local rel = path:sub(#S.root + 2)
  local parts = vim.split(rel, "/", { plain = true })
  local acc = S.root
  for i = 1, #parts - 1 do
    acc = tree.join(acc, parts[i])
    S.open_dirs[acc] = true
  end

  -- Register the target.  render.render() will pick this up in its build
  -- callback (render._reveal_cursor) after S.items is repopulated.
  S._reveal_target = path
  render.render()
end

-- ── open ─────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  local cw = api.nvim_get_current_win()
  if is_regular_edit_window(cw) then
    S.prev_win = cw
  end

  -- Determine if we should force a root re-detection.
  -- We re-detect if:
  -- 1. No root is currently set.
  -- 2. The explorer is currently closed (toggled on).
  -- 3. The current buffer is outside the existing root.
  local current_buf_path = tree.norm(fn.fnamemodify(api.nvim_buf_get_name(0), ":p"))
  local in_root = S.root and (current_buf_path == S.root or vim.startswith(current_buf_path, S.root .. "/"))
  local needs_redetect = not S.root
    or not (S.win and api.nvim_win_is_valid(S.win))
    or (current_buf_path ~= "" and not in_root)

  local requested_root = opts.root or (not needs_redetect and S.root) or find_project_root()
  local new_root = tree.norm(fn.fnamemodify(requested_root, ":p"))

  -- Record the old root as a recent entry before switching
  if S.root and S.root ~= new_root then
    store.push_recent(S.root)
    -- Clear open dirs when switching projects to avoid showing stale state
    S.open_dirs = {}
    -- Clear the scan cache to avoid stale entries from the old project
    S.scan_cache = {}
    -- Invalidate git repo cache for the new root so git.fetch() re-checks
    -- whether new_root is actually a git repository.
    git.invalidate_repo_cache(new_root)
    -- Clear active path — it may belong to the old project.
    S.active_buf_path = nil
  end

  S.root = new_root

  -- Seed the active-buffer path so the indicator appears on first paint.
  do
    local p = api.nvim_buf_get_name(0)
    if p and p ~= "" and not p:match("^explorer://") then
      local np = tree.norm(fn.fnamemodify(p, ":p"))
      if vim.startswith(np, new_root) then
        S.active_buf_path = np
      end
    end
  end

  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    S.buf = win.make_buf()
    win.setup_keymaps(S.buf)
  end
  if S.buf and api.nvim_buf_is_valid(S.buf) and not vim.b[S.buf]._explorer_tree_guard then
    api.nvim_create_autocmd("CursorMoved", {
      group = api.nvim_create_augroup("ExplorerCursorGuard_" .. S.buf, { clear = true }),
      buffer = S.buf,
      callback = function()
        if S.search_active then
          return
        end
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end
        local row = api.nvim_win_get_cursor(S.win)[1]
        if row <= search_ui.HEADER_LINES and #S.items > 0 then
          pcall(api.nvim_win_set_cursor, S.win, { search_ui.line_for_item(1), 0 })
        end
      end,
    })
    vim.b[S.buf]._explorer_tree_guard = true
  end

  S.icon_fn = icons.resolve()

  if not (S.win and api.nvim_win_is_valid(S.win)) then
    S.win = win.make_win(S.buf)
  else
    win.update_winbar()
  end

  -- Wire search keymaps/autocmds to S.buf once per buffer lifetime.
  if S.buf and api.nvim_buf_is_valid(S.buf) and not vim.b[S.buf]._explorer_search_setup then
    search.setup(S.buf)
    vim.b[S.buf]._explorer_search_setup = true
  end

  -- Always schedule a render so the tree is populated.
  render.render()
  search_ui.paint()
  git.fetch()
  watch_start()

  -- Identify the file from the previously focused window and reveal it.
  -- M.reveal() will either:
  --   a) Position the cursor immediately if the file is already in S.items, or
  --   b) Register S._reveal_target and call render.render() (which is
  --      debounced — the already-pending build above will pick up the target,
  --      so no second build is started).
  local src = (cw == S.win) and 0 or api.nvim_win_get_buf(cw)
  local path = fn.fnamemodify(api.nvim_buf_get_name(src), ":p")
  if path and path ~= "" and path ~= "/" then
    M.reveal(path)
  end

  api.nvim_set_current_win(S.win)
end

-- ── close ────────────────────────────────────────────────────────────────

function M.close(opts)
  opts = opts or {}
  search.close()
  watch_stop()
  if S.win and api.nvim_win_is_valid(S.win) then
    local w = S.win
    S.win = nil
    pcall(api.nvim_win_close, w, true)
  else
    S.win = nil
  end
  if opts.wipe and S.buf and api.nvim_buf_is_valid(S.buf) then
    local buf = S.buf
    S.buf = nil
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

-- ── toggle ───────────────────────────────────────────────────────────────

function M.toggle(opts)
  if S.win and api.nvim_win_is_valid(S.win) then
    M.close()
  else
    M.open(opts)
  end
end

function M.session_snapshot()
  local is_open = S.win and api.nvim_win_is_valid(S.win)
  if not is_open then
    return { open = false }
  end

  local current_buf = api.nvim_get_current_buf()
  local active_path = fn.fnamemodify(api.nvim_buf_get_name(current_buf), ":p")
  if active_path == "" or not vim.startswith(tree.norm(active_path), S.root or "") then
    active_path = nil
  end

  return {
    open = true,
    root = S.root,
    open_dirs = open_dirs_to_list(),
    active_path = active_path,
  }
end

function M.restore_session(snapshot)
  if not did_setup or type(snapshot) ~= "table" or not snapshot.open then
    return false
  end

  local root = snapshot.root and tree.norm(fn.fnamemodify(snapshot.root, ":p")) or nil
  if not root or fn.isdirectory(root) ~= 1 then
    return false
  end

  S.root = root
  S.scan_cache = {}
  S.open_dirs = list_to_open_dirs(snapshot.open_dirs)
  S.filter = nil
  S.search_active = false
  S._reveal_target = nil

  local winid, buf = find_existing_window()
  if winid and buf then
    S.win = winid
    S.buf = buf
    win.apply_window_options(winid)
    win.setup_keymaps(buf)
    if not vim.b[buf]._explorer_search_setup then
      search.setup(buf)
      vim.b[buf]._explorer_search_setup = true
    end
    win.update_winbar()
  else
    local current = api.nvim_get_current_win()
    M.open({ root = root })
    if api.nvim_win_is_valid(current) and current ~= S.win then
      pcall(api.nvim_set_current_win, current)
    end
  end

  S.icon_fn = icons.resolve()
  render.render()
  git.fetch()
  watch_start()

  if snapshot.active_path and snapshot.active_path ~= "" then
    M.reveal(snapshot.active_path)
  end

  return true
end

-- ── setup ────────────────────────────────────────────────────────────────

function M.setup(opts)
  if did_setup then
    return
  end
  did_setup = true
  cfg.current = vim.tbl_deep_extend("force", cfg.defaults, opts or {})
  local c = cfg.current
  local km = c.keymaps
  S.close_fn = M.close

  -- Register the DiagnosticChanged autocmd for folder-level severity badges.
  -- This is a global listener; apply() itself guards on S.buf validity.
  diag.setup()

  nvim_utils.command("Explorer", function(a)
    M.toggle({ root = a.args ~= "" and a.args or nil })
  end, { nargs = "?", complete = "dir", desc = "Toggle file explorer" })

  nvim_utils.command("ExplorerReveal", function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      M.open()
    end
    M.reveal(api.nvim_buf_get_name(0))
  end, { desc = "Reveal current file in explorer" })

  nvim_utils.command("ExplorerProjects", function()
    require("custom.explorer.projects").open()
  end, { desc = "Open project switcher" })

  nvim_utils.command("ExplorerProjectPin", function()
    local root = find_project_root()
    store.add_pinned(root)
    vim.notify("[explorer] pinned project root: " .. fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
  end, { desc = "Pin current project root" })

  vim.keymap.set("n", "<leader>e", function()
    M.toggle()
  end, { desc = "Toggle explorer" })

  nvim_utils.autocmd("ColorScheme", {
    desc = "explorer: refresh highlights",
    callback = function()
      win.reset_hl()
      win.ensure_hl()
      git.clear_sign_cache() -- glyph widths may differ across fonts/themes
      -- The project-aware accent in ensure_hl() reads S.root; no additional
      -- action needed here.  The repo-existence cache is root-keyed, so a
      -- colorscheme change (which doesn't change root) doesn't need a cache
      -- clear.
      S.icon_fn = icons.resolve()
      if S.buf and api.nvim_buf_is_valid(S.buf) then
        render._paint()
        search_ui.paint()
        git.apply()
      end
    end,
  })

  nvim_utils.autocmd({ "VimResized", "WinResized" }, {
    desc = "explorer: reposition persistent search UI",
    callback = function()
      if S.win and api.nvim_win_is_valid(S.win) then
        search_ui.paint()
      end
    end,
  })

  nvim_utils.autocmd("WinScrolled", {
    desc = "explorer: repaint header only on width change",
    callback = function()
      if not (S.win and api.nvim_win_is_valid(S.win)) then
        return
      end
      local ev = vim.v.event
      local changed = ev and ev[tostring(S.win)]
      if changed and (changed.width or 0) ~= 0 then
        search_ui.paint()
      end
    end,
  })

  -- ── follow_file ────────────────────────────────────────────────────────
  --
  -- Tracks the active buffer and moves the explorer cursor to match.
  --
  -- Debounce: 150ms.  Rapid buffer switches collapse to the last one, so
  -- quickly navigating through a quickfix list doesn't stutter the explorer.
  --
  -- Fast/slow path: M.reveal() first scans S.items in O(n).  If the file is
  -- already visible it just moves the cursor — no rebuild.  Only if a parent
  -- directory needs expanding does it trigger a tree rebuild.
  --
  -- Guard: skip if the event fires because focus moved INTO the explorer
  -- itself (prevents the explorer buffer's BufEnter from triggering a reveal).

  if c.follow_file then
    local _follow_timer = nil
    nvim_utils.autocmd("BufEnter", {
      desc = "explorer: follow active buffer",
      callback = function(ev)
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end

        local buf = ev.buf
        if not (buf and api.nvim_buf_is_valid(buf)) then
          return
        end

        -- If current window is the explorer...
        if api.nvim_get_current_win() == S.win then
          -- If the explorer window was hijacked by a regular buffer (e.g. via tabline click), restore it.
          if buf ~= S.buf and vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "explorer" then
            vim.schedule(function()
              if S.win and api.nvim_win_is_valid(S.win) and S.buf and api.nvim_buf_is_valid(S.buf) then
                api.nvim_win_set_buf(S.win, S.buf)
              end
            end)
          end
          return
        end

        if vim.bo[buf].buftype ~= "" then
          return
        end
        if S.search_active then
          return
        end
        local path = api.nvim_buf_get_name(buf)
        if path == "" then
          return
        end

        -- Cancel any pending follow for a previous buffer
        if _follow_timer then
          _follow_timer:stop()
          _follow_timer = nil
        end

        -- Short debounce so rapid buffer switches (quickfix nav, etc.)
        -- don't each trigger a separate tree scan/rebuild.
        _follow_timer = vim.defer_fn(function()
          _follow_timer = nil
          -- Track the active buffer path so render.lua can highlight it.
          local norm_path = tree.norm(fn.fnamemodify(path, ":p"))
          S.active_buf_path = norm_path
          M.reveal(norm_path)
        end, 150)
      end,
    })
  end

  nvim_utils.autocmd({ "WinEnter", "BufWinEnter" }, {
    desc = "explorer: track previous edit window",
    callback = function()
      local winid = api.nvim_get_current_win()
      if is_regular_edit_window(winid) then
        S.prev_win = winid
        -- Keep active_buf_path in sync even when follow_file is off.
        -- This is cheap (no rebuild) — render._paint() reads it on next repaint.
        local p = api.nvim_buf_get_name(api.nvim_win_get_buf(winid))
        if p and p ~= "" and S.root then
          local np = tree.norm(fn.fnamemodify(p, ":p"))
          if vim.startswith(np, S.root) then
            if S.active_buf_path ~= np then
              S.active_buf_path = np
              -- Repaint the active layer without a full rebuild
              if S.buf and api.nvim_buf_is_valid(S.buf) then
                require("custom.explorer.render").apply_active_indicator()
              end
            end
          end
        end
      end
    end,
  })

  nvim_utils.autocmd("WinClosed", {
    desc = "explorer: cleanup on close",
    callback = function(ev)
      local closed = tonumber(ev.match)
      if closed == S.win then
        S.win = nil
        watch_stop()
        search.close()
      end
      vim.schedule(function()
        local wins = vim.tbl_filter(function(w)
          return api.nvim_win_is_valid(w) and api.nvim_win_get_config(w).relative == ""
        end, api.nvim_list_wins())
        if #wins == 1 and S.win and api.nvim_win_is_valid(S.win) and wins[1] == S.win then
          vim.cmd("quit")
        end
      end)
    end,
  })

  nvim_utils.autocmd({ "WinLeave", "BufLeave" }, {
    desc = "explorer: restore width after focus leaves",
    callback = function(ev)
      if
        S.win
        and api.nvim_win_is_valid(S.win)
        and (api.nvim_get_current_win() == S.win or (S.buf and ev.buf == S.buf))
      then
        win.reset_width()
      end
    end,
  })

  nvim_utils.autocmd("FileType", {
    pattern = "explorer",
    desc = "explorer: enforce buffer options",
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return M
