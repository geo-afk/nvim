-- custom/explorer/init.lua
-- Usage: require("custom.explorer").setup()

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
      end -- don't interrupt while user is typing
      if _debounce then
        _debounce:stop()
      end
      _debounce = vim.defer_fn(function()
        _debounce = nil
        render.render()
        git.fetch()
      end, 500) -- 500ms — was 250ms; the higher value prevents flicker
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
-- S.items[i] → line i+1.  Cursor row = i+1.

function M.reveal(path)
  if not path or path == '' then
    return
  end
  path = tree.norm(fn.fnamemodify(path, ':p'))
  if not vim.startswith(path, S.root) then
    return
  end
  if S.search_active then
    return
  end -- don't disrupt active search

  if S.win and api.nvim_win_is_valid(S.win) then
    local row = api.nvim_win_get_cursor(S.win)[1]
    if row >= 2 then
      local cur = S.items[row - 1]
      if cur and cur.path == path then
        return
      end -- already there
    end
  end

  local rel = path:sub(#S.root + 2)
  local parts = vim.split(rel, '/', { plain = true })
  local acc = S.root
  for i = 1, #parts - 1 do
    acc = tree.join(acc, parts[i])
    S.open_dirs[acc] = true
  end

  S.build_tok = S.build_tok + 1
  local tok = S.build_tok
  tree.build(
    tok,
    S.filter,
    vim.schedule_wrap(function(items)
      if S.build_tok ~= tok then
        return
      end
      S.items = items
      render._paint()
      git.apply()
      vim.schedule(function()
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end
        for i, it in ipairs(S.items) do
          if it.path == path then
            pcall(api.nvim_win_set_cursor, S.win, { i + 1, 0 }) -- line i+1
            return
          end
        end
      end)
    end)
  )
end

-- ── open ─────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  local cw = api.nvim_get_current_win()
  if cw ~= S.win then
    S.prev_win = cw
  end

  S.root = tree.norm(fn.fnamemodify(opts.root or fn.getcwd(), ':p'))

  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    S.buf = win.make_buf()
    win.setup_keymaps(S.buf)
    search.setup(S.buf) -- attach inline search autocmds + keymaps
  end

  S.icon_fn = icons.resolve()

  if not (S.win and api.nvim_win_is_valid(S.win)) then
    S.win = win.make_win(S.buf)
  end

  render.render()
  git.fetch()
  watch_start()

  local src = (cw == S.win) and 0 or api.nvim_win_get_buf(cw)
  local path = fn.fnamemodify(api.nvim_buf_get_name(src), ':p')
  if path and path ~= '' and path ~= '/' then
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
  cfg.current = vim.tbl_deep_extend('force', cfg.defaults, opts or {})
  local c = cfg.current
  local km = c.keymaps
  S.close_fn = M.close

  api.nvim_create_user_command('Explorer', function(a)
    M.toggle { root = a.args ~= '' and a.args or nil }
  end, { nargs = '?', complete = 'dir', desc = 'Toggle file explorer' })

  api.nvim_create_user_command('ExplorerReveal', function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      M.open()
    end
    M.reveal(api.nvim_buf_get_name(0))
  end, { desc = 'Reveal current file in explorer' })

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

  api.nvim_create_autocmd('ColorScheme', {
    desc = 'explorer: refresh highlights',
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

  -- follow_file: debounced so rapid buffer switches don't cause flicker
  if c.follow_file then
    local _follow_timer = nil
    api.nvim_create_autocmd('BufEnter', {
      desc = 'explorer: follow active buffer',
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
        if S.search_active then
          return
        end
        local path = api.nvim_buf_get_name(0)
        if path == '' then
          return
        end
        if _follow_timer then
          _follow_timer:stop()
        end
        _follow_timer = vim.defer_fn(function()
          _follow_timer = nil
          M.reveal(path)
        end, 150) -- 150ms debounce — prevents flicker on quick buffer switches
      end,
    })
  end

  api.nvim_create_autocmd('WinClosed', {
    desc = 'explorer: cleanup on close',
    callback = function(ev)
      local closed = tonumber(ev.match)
      if closed == S.win then
        S.win = nil
        watch_stop()
        search.close()
      end
      vim.schedule(function()
        local wins = vim.tbl_filter(function(w)
          return api.nvim_win_is_valid(w) and api.nvim_win_get_config(w).relative == ''
        end, api.nvim_list_wins())
        if #wins == 1 and S.win and api.nvim_win_is_valid(S.win) and wins[1] == S.win then
          vim.cmd 'quit'
        end
      end)
    end,
  })

  api.nvim_create_autocmd('FileType', {
    pattern = 'explorer',
    desc = 'explorer: enforce buffer options',
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return M
