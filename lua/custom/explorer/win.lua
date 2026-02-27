-- explorer/win.lua
-- Window/buffer creation, highlight groups, buffer keymaps.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local git = require 'custom.explorer.git'
local marks = require 'custom.explorer.marks'
local icons = require 'custom.explorer.icons'
local api = vim.api

local M = {}

-------------------------------------------------------------------------------
-- Highlight groups
-------------------------------------------------------------------------------
function M.ensure_hl()
  -- Guard: if already defined, skip (reset by M.reset_hl on ColorScheme)
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = 'ExplorerNormal' })
  if ok and ex and next(ex) then
    return
  end

  local function get(n)
    local h = api.nvim_get_hl(0, { name = n, link = false })
    return h or {}
  end
  local function def(n, o)
    pcall(api.nvim_set_hl, 0, n, o)
  end

  local normal = get 'Normal'
  local float_ = get 'NormalFloat'
  local cursor = get 'CursorLine'
  local comment = get 'Comment'
  local pmenu = get 'Pmenu'

  local sidebar_bg = float_.bg or normal.bg
  local bar_bg = pmenu.bg or float_.bg or normal.bg
  local dim_fg = comment.fg or 0x565f89

  local function accent_fg()
    for _, n in ipairs { 'Function', 'Special', 'Statement' } do
      local h = get(n)
      if h.fg then
        return h.fg
      end
    end
    return 0x7aa2f7
  end
  local accent = accent_fg()

  -- ── Sidebar ───────────────────────────────────────────────────────────────
  def('ExplorerNormal', { bg = sidebar_bg, fg = normal.fg })
  def('ExplorerCursorLine', { bg = cursor.bg or 'NONE', bold = true })

  -- ── Search bar ────────────────────────────────────────────────────────────
  def('ExplorerSearchBar', { bg = bar_bg, fg = normal.fg })
  def('ExplorerSearchIcon', { bg = bar_bg, fg = accent, bold = true })
  def('ExplorerSearchPlaceholder', { bg = bar_bg, fg = dim_fg, italic = true })

  -- ── Separator line (between search bar and tree) ──────────────────────────
  def('ExplorerSeparator', { fg = dim_fg, bg = sidebar_bg })

  -- ── Git + marks ───────────────────────────────────────────────────────────
  git.setup_hl()
  marks.setup_hl()
end

function M.reset_hl()
  local names = {
    'ExplorerNormal',
    'ExplorerCursorLine',
    'ExplorerSearchBar',
    'ExplorerSearchIcon',
    'ExplorerSearchPlaceholder',
    'ExplorerSeparator',
    'ExplorerGitAdded',
    'ExplorerGitModified',
    'ExplorerGitDeleted',
    'ExplorerGitRenamed',
    'ExplorerGitUntracked',
    'ExplorerGitConflict',
    'ExplorerGitIgnored',
    'ExplorerGitAddedLine',
    'ExplorerGitModifiedLine',
    'ExplorerGitDeletedLine',
    'ExplorerGitRenamedLine',
    'ExplorerGitUntrackedLine',
    'ExplorerGitConflictLine',
    'ExplorerGitIgnoredLine',
    'ExplorerMark',
  }
  for _, name in ipairs(names) do
    pcall(api.nvim_set_hl, 0, name, {})
  end
end

-------------------------------------------------------------------------------
-- Buffer
-------------------------------------------------------------------------------
function M.make_buf()
  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, buf, 'explorer://')
  local bo = vim.bo[buf]
  bo.buftype = 'nofile'
  bo.bufhidden = 'hide'
  bo.buflisted = false
  bo.filetype = 'explorer' -- used by bufferline offsets
  bo.modifiable = false
  bo.swapfile = false
  return buf
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
function M.make_win(buf)
  M.ensure_hl()
  local c = cfg.get()
  local side = c.side == 'right' and 'botright' or 'topleft'
  vim.cmd(side .. ' ' .. c.width .. 'vsplit')
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)

  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  wo.winfixwidth = true
  wo.wrap = false
  wo.spell = false
  wo.list = false
  wo.cursorline = true
  wo.fillchars = 'eob: '
  -- No winbar: the search float replaces it entirely.
  -- Explicitly blank it so other plugins don't inject one.
  pcall(function()
    wo.winbar = ''
  end)
  pcall(function()
    wo.statuscolumn = ''
  end)
  pcall(function()
    wo.foldcolumn = '0'
  end)
  wo.winhl = 'Normal:ExplorerNormal,CursorLine:ExplorerCursorLine'

  S.icon_fn = icons.resolve()
  return win
end

-------------------------------------------------------------------------------
-- Keymaps (set once on the tree buffer)
-------------------------------------------------------------------------------
function M.setup_keymaps(buf)
  local km = cfg.get().keymaps
  local A = require 'custom.explorer.actions'
  local opts = { noremap = true, silent = true, nowait = true, buffer = buf }

  local function map(keys, action)
    if type(keys) == 'string' then
      keys = { keys }
    end
    for _, k in ipairs(keys) do
      if k and k ~= '' then
        vim.keymap.set('n', k, action, opts)
      end
    end
  end

  map(km.open, A.open_or_toggle)
  map(km.close_dir, A.close_dir)
  map(km.go_up, A.go_up)
  map(km.vsplit, A.vsplit)
  map(km.split, A.split)
  map(km.tab, A.tab_open)
  map(km.add, A.add)
  map(km.delete, A.delete)
  map(km.rename, A.rename)
  map(km.copy, A.copy)
  map(km.toggle_hidden, A.toggle_hidden)
  map(km.refresh, A.refresh)
  map(km.copy_path, A.copy_path)
  map(km.file_info, A.file_info)
  map(km.mark, A.toggle_mark)
  map(km.collapse_all, A.collapse_all)
  map(km.expand_all, function()
    A.expand_all(1)
  end)
  map(km.git_stage, A.git_stage)
  map(km.git_restore, A.git_restore)
  map(km.help, A.show_help)

  -- "/" activates the search bar
  map(km.search, function()
    require('custom.explorer.search').activate()
  end)

  -- "q" closes via the injected close_fn (avoids hard require("explorer"))
  map(km.quit, function()
    if S.close_fn then
      S.close_fn()
    end
  end)
end

return M
