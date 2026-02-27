-- explorer/init.lua
-- Public API: setup(), open(), close(), toggle(), reveal()
--
-- ┌─────────────────────────────────────────────────────────────────┐
-- │  DROP-IN INSTALL                                                │
-- │  Copy the entire  lua/explorer/  folder to:                     │
-- │    ~/.config/nvim/lua/explorer/                                 │
-- │  Then in init.lua:                                              │
-- │    require("explorer").setup()                                  │
-- │                                                                 │
-- │  BUFFERLINE OFFSET (add to bufferline.setup options):           │
-- │    offsets = {{ filetype="explorer", text="Explorer",           │
-- │                 separator=true }}                               │
-- └─────────────────────────────────────────────────────────────────┘

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local tree = require 'custom.explorer.tree'
local render = require 'custom.explorer.render'
local git = require 'custom.explorer.git'
local win = require 'custom.explorer.win'
local search = require 'custom.explorer.search'
local icons = require 'custom.explorer.icons'

local api = vim.api
local fn = vim.fn

local M = {}

-- ── File watcher ──────────────────────────────────────────────────────────

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
  local ok = w:start(S.root, { recursive = true }, function(err)
    if err then
      return
    end
    if _debounce then
      _debounce:stop()
    end
    _debounce = vim.defer_fn(function()
      _debounce = nil
      render.render()
      git.fetch()
    end, 250)
  end)
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

-- ── Reveal ────────────────────────────────────────────────────────────────
-- Opens all ancestor directories of `path` and moves the cursor to it.

function M.reveal(path)
  if not path or path == '' then
    return
  end
  path = tree.norm(fn.fnamemodify(path, ':p'))
  if not vim.startswith(path, S.root) then
    return
  end

  -- Short-circuit: already on this path
  if S.win and api.nvim_win_is_valid(S.win) then
    local row = api.nvim_win_get_cursor(S.win)[1]
    local cur = S.items[row]
    if cur and cur.path == path then
      return
    end
  end

  -- Expand ancestors
  local rel = path:sub(#S.root + 2)
  local parts = vim.split(rel, '/', { plain = true })
  local acc = S.root
  for i = 1, #parts - 1 do
    acc = tree.join(acc, parts[i])
    S.open_dirs[acc] = true
  end

  -- Rebuild with no filter so the file is guaranteed to be in the list
  S.build_tok = S.build_tok + 1
  local tok = S.build_tok
  local c = cfg.get()
  tree.build(tok, S.filter, function(items)
    S.items = items
    render._paint()
    git.apply()
    vim.schedule(function()
      for i, it in ipairs(S.items) do
        if it.path == path then
          -- +1: header occupies buffer line 1; items start at line 2
          pcall(api.nvim_win_set_cursor, S.win, { i + 1, 0 })
          return
        end
      end
    end)
  end)
end

-- ── Open ──────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  local c = cfg.get()
  local cw = api.nvim_get_current_win()
  if cw ~= S.win then
    S.prev_win = cw
  end

  S.root = tree.norm(fn.fnamemodify(opts.root or fn.getcwd(), ':p'))

  -- Buffer (created once per session)
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    S.buf = win.make_buf()
    win.setup_keymaps(S.buf)
  end

  S.icon_fn = icons.resolve()

  -- Window
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    S.win = win.make_win(S.buf)
  end

  render.render()
  git.fetch()
  watch_start()

  if c.follow_file then
    local src = (cw == S.win) and 0 or api.nvim_win_get_buf(cw)
    local path = api.nvim_buf_get_name(src)
    if path and path ~= '' then
      M.reveal(path)
    end
  end

  api.nvim_set_current_win(S.win)
end

-- ── Close ─────────────────────────────────────────────────────────────────

function M.close()
  search.close()
  watch_stop()
  if S.win and api.nvim_win_is_valid(S.win) then
    local w = S.win
    S.win = nil -- nil BEFORE close to prevent WinClosed re-entrance
    pcall(api.nvim_win_close, w, true)
  else
    S.win = nil
  end
end

-- ── Toggle ────────────────────────────────────────────────────────────────
-- One press always toggles visibility (not focus). Use reveal (<leader>E)
-- to move focus into the explorer without closing it.

function M.toggle(opts)
  if S.win and api.nvim_win_is_valid(S.win) then
    M.close()
  else
    M.open(opts)
  end
end

-- ── Setup ─────────────────────────────────────────────────────────────────

function M.setup(opts)
  cfg.current = vim.tbl_deep_extend('force', cfg.defaults, opts or {})
  local c = cfg.current
  local km = c.keymaps

  -- Store close function in state so win.lua can call it without a hard
  -- require("explorer") that would fail if the module lives at a different path.
  S.close_fn = M.close

  -- Commands
  api.nvim_create_user_command('Explorer', function(a)
    M.toggle { root = a.args ~= '' and a.args or nil }
  end, { nargs = '?', complete = 'dir', desc = 'Toggle file explorer' })

  api.nvim_create_user_command('ExplorerReveal', function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      M.open()
    end
    M.reveal(api.nvim_buf_get_name(0))
  end, { desc = 'Reveal current file in explorer' })

  -- Global keymaps
  if km.toggle and km.toggle ~= '' then
    vim.keymap.set('n', km.toggle, M.toggle, { silent = true, desc = 'Toggle explorer' })
  end
  if km.reveal and km.reveal ~= '' then
    vim.keymap.set('n', km.reveal, function()
      if not (S.win and api.nvim_win_is_valid(S.win)) then
        M.open()
      end
      M.reveal(api.nvim_buf_get_name(0))
      if S.win and api.nvim_win_is_valid(S.win) then
        api.nvim_set_current_win(S.win)
      end
    end, { silent = true, desc = 'Reveal file in explorer' })
  end

  -- Re-derive highlights on colorscheme change
  api.nvim_create_autocmd('ColorScheme', {
    desc = 'explorer: refresh highlights',
    callback = function()
      win.reset_hl()
      win.ensure_hl()
      S.icon_fn = icons.resolve()
    end,
  })

  -- BufEnter follow
  if c.follow_file then
    api.nvim_create_autocmd('BufEnter', {
      desc = 'explorer: reveal active buffer',
      callback = function()
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end
        if api.nvim_get_current_win() == S.win then
          return
        end
        if vim.bo.buftype ~= '' then
          return
        end
        local path = api.nvim_buf_get_name(0)
        if path ~= '' then
          M.reveal(path)
        end
      end,
    })
  end

  -- WinClosed: clean up, quit if explorer is last window
  api.nvim_create_autocmd('WinClosed', {
    desc = 'explorer: cleanup on close',
    callback = function(ev)
      local closed = tonumber(ev.match)
      if closed == S.win then
        S.win = nil
        watch_stop()
        search.close()
      end
      -- Quit Neovim if the only remaining non-float window is the explorer
      vim.schedule(function()
        local normal = vim.tbl_filter(function(w)
          return api.nvim_win_is_valid(w) and api.nvim_win_get_config(w).relative == ''
        end, api.nvim_list_wins())
        if #normal == 1 and S.win and api.nvim_win_is_valid(S.win) and normal[1] == S.win then
          vim.cmd 'quit'
        end
      end)
    end,
  })

  -- Enforce buffer options
  api.nvim_create_autocmd('FileType', {
    pattern = 'explorer',
    desc = 'explorer: enforce nolist etc.',
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return M
