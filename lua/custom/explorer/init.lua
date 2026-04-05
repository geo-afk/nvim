-- custom/explorer/init.lua
-- Usage: require("custom.explorer").setup()

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local render = require("custom.explorer.render")
local git = require("custom.explorer.git")
local win = require("custom.explorer.win")
local search = require("custom.explorer.search")
local icons = require("custom.explorer.icons")
local store = require("custom.explorer.project_store")
local nvim_utils = require("utils.nvim")

local api = vim.api
local fn = vim.fn
local M = {}

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
  local uv = vim.uv or vim.loop
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
        if cur_row == i + 1 then
          return
        end -- already there, nothing to do
        pcall(api.nvim_win_set_cursor, S.win, { i + 1, 0 })
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
  if cw ~= S.win then
    S.prev_win = cw
  end

  local requested_root = opts.root or S.root or fn.getcwd()
  local new_root = tree.norm(fn.fnamemodify(requested_root, ":p"))

  -- Record the old root as a recent entry before switching
  if S.root and S.root ~= new_root then
    for i, r in ipairs(S.recent_roots) do
      if r == S.root then
        table.remove(S.recent_roots, i)
        break
      end
    end
    table.insert(S.recent_roots, 1, S.root)
    while #S.recent_roots > 20 do
      table.remove(S.recent_roots)
    end
    store.push_recent(S.root)
  end

  S.root = new_root

  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    S.buf = win.make_buf()
    win.setup_keymaps(S.buf)
    search.setup(S.buf)
  end

  S.icon_fn = icons.resolve()

  if not (S.win and api.nvim_win_is_valid(S.win)) then
    S.win = win.make_win(S.buf)
  end

  -- Always schedule a render so the tree is populated.
  render.render()
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

function M.close()
  search.close()
  watch_stop()
  if S.win and api.nvim_win_is_valid(S.win) then
    local w = S.win
    S.win = nil
    pcall(api.nvim_win_close, w, true)
  else
    S.win = nil
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

-- ── setup ────────────────────────────────────────────────────────────────

function M.setup(opts)
  cfg.current = vim.tbl_deep_extend("force", cfg.defaults, opts or {})
  local c = cfg.current
  local km = c.keymaps
  S.close_fn = M.close
  S.recent_roots = store.get_recent()

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

  if km.toggle and km.toggle ~= "" then
    nvim_utils.map("n", km.toggle, M.toggle, { silent = true, desc = "Toggle explorer" })
  end
  if km.reveal and km.reveal ~= "" then
    nvim_utils.map("n", km.reveal, function()
      if not (S.win and api.nvim_win_is_valid(S.win)) then
        M.open()
      end
      M.reveal(api.nvim_buf_get_name(0))
      if S.win and api.nvim_win_is_valid(S.win) then
        api.nvim_set_current_win(S.win)
      end
    end, { silent = true, desc = "Reveal file in explorer" })
  end

  nvim_utils.autocmd("ColorScheme", {
    desc = "explorer: refresh highlights",
    callback = function()
      win.reset_hl()
      win.ensure_hl()
      S.icon_fn = icons.resolve()
      if S.buf and api.nvim_buf_is_valid(S.buf) then
        render._paint()
        git.apply()
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
      callback = function()
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end
        if api.nvim_get_current_win() == S.win then
          return
        end
        if vim.bo.buftype ~= "" then
          return
        end
        if S.search_active then
          return
        end
        local path = api.nvim_buf_get_name(0)
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
          M.reveal(path)
        end, 150)
      end,
    })
  end

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

  nvim_utils.autocmd("FileType", {
    pattern = "explorer",
    desc = "explorer: enforce buffer options",
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return M
