-- custom/explorer/win.lua
-- Window creation, highlight groups, keymaps.

local S    = require 'custom.explorer.state'
local cfg  = require 'custom.explorer.config'
local git  = require 'custom.explorer.git'
local marks = require 'custom.explorer.marks'
local icons = require 'custom.explorer.icons'
local api  = vim.api

local M = {}

-- ── Colour helpers ────────────────────────────────────────────────────────

-- Decode a packed 0xRRGGBB integer into r,g,b (0–255)
local function unpack_rgb(c)
  return math.floor(c / 0x10000) % 0x100,
         math.floor(c / 0x100)   % 0x100,
         c % 0x100
end

-- Linear blend: returns colour that is `t` of `a` and `(1-t)` of `b`
local function blend(a, b, t)
  local ar, ag, ab_ = unpack_rgb(a)
  local br, bg, bb  = unpack_rgb(b)
  local lerp = function(x, y) return math.floor(x * t + y * (1 - t) + 0.5) end
  return lerp(ar, br) * 0x10000 + lerp(ag, bg) * 0x100 + lerp(ab_, bb)
end

-- Lighten or darken by absolute delta (-255..255 per channel)
local function nudge(c, delta)
  local r, g, b = unpack_rgb(c)
  local clamp = function(v) return math.max(0, math.min(255, v)) end
  return clamp(r + delta) * 0x10000 + clamp(g + delta) * 0x100 + clamp(b + delta)
end

local function get(name)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = name, link = false })
  return ok and h or {}
end

local function def(name, opts)
  pcall(api.nvim_set_hl, 0, name, opts)
end

local function fg_of(...)
  for _, n in ipairs { ... } do
    local h = get(n)
    if h.fg then return h.fg end
  end
end

local function bg_of(...)
  for _, n in ipairs { ... } do
    local h = get(n)
    if h.bg then return h.bg end
  end
end

-- ── Highlight system ──────────────────────────────────────────────────────
--
-- Design goals
--   • Sidebar bg matches NormalFloat so it looks like a panel, not a split
--   • CursorLine is a soft wash — NOT bold text — avoids visual noise
--   • Tree connectors are barely visible: they guide the eye without competing
--   • Search bar has a micro-tinted bg to read as an "input zone"
--   • Active search state uses the accent colour prominently
--   • Git signs use subdued backgrounds; only the sign glyph is vivid

function M.ensure_hl()
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = 'ExplorerNormal' })
  if ok and ex and next(ex) then return end

  -- ── Source colours from the active colorscheme ─────────────────────
  local normal   = get 'Normal'
  local float_   = get 'NormalFloat'
  local comment  = get 'Comment'
  local cursor   = get 'CursorLine'
  local pmenu    = get 'Pmenu'
  local visual   = get 'Visual'

  -- Sidebar background: prefer NormalFloat; fall back to a slightly
  -- darkened Normal so the panel always looks distinct.
  local editor_bg  = normal.bg  or 0x1e1e2e
  local sidebar_bg = float_.bg  or pmenu.bg or nudge(editor_bg, -8)
  -- Guarantee it's at least a little different from the editor bg
  if sidebar_bg == editor_bg then
    sidebar_bg = nudge(editor_bg, -10)
  end

  -- Foreground colours
  local normal_fg = normal.fg  or 0xcdd6f4
  local dim_fg    = comment.fg or 0x585b70

  -- Accent: prefer @function / Function for warm theme compat
  local accent  = fg_of('Function', '@function', 'Special', 'Statement') or 0xcba6f7
  local dir_fg  = fg_of('Directory', '@namespace', 'Special')             or 0x89b4fa
  local str_fg  = fg_of('String', '@string', 'Constant')                  or 0xa6e3a1

  -- ── Core sidebar ──────────────────────────────────────────────────
  def('ExplorerNormal',     { bg = sidebar_bg, fg = normal_fg })

  -- CursorLine: a very soft accent wash — no bold weight
  local cursor_bg = cursor.bg or blend(accent, sidebar_bg, 0.10)
  def('ExplorerCursorLine', { bg = cursor_bg })

  def('ExplorerDirectory',  { fg = dir_fg, bold = true })

  -- Connectors: blend deeply toward bg so they read as "guides" not text
  def('ExplorerConnector',  { fg = blend(dim_fg, sidebar_bg, 0.35) })

  -- ── Inline search bar (row 0) ─────────────────────────────────────
  --
  --  States (left → right reading):
  --
  --  Idle/empty  │ [search-bg]  󰍉  filter files…        [dim icon + placeholder]
  --              │ ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ (muted dashes)
  --
  --  Filter set  │ [search-bg]  󰍉  lua    3 of 42 ›     [accent icon + count badge]
  --              │ ─────────────────────── (dim solid)
  --
  --  Active      │ [active-bg]  󰍉  lua_                 [bright icon + cursor]
  --              │ ─────────────────────── (accent solid)
  --
  -- The search row bg is a *very* subtle accent tint so it reads as an
  -- input area without screaming for attention.
  local search_bg        = blend(accent, sidebar_bg, 0.055)
  local search_active_bg = blend(accent, sidebar_bg, 0.10)

  def('ExplorerSearchBg',           { bg = search_bg,        fg = normal_fg })
  def('ExplorerSearchBgActive',     { bg = search_active_bg, fg = normal_fg })

  -- Icon: muted when idle, vivid when active
  local icon_idle = blend(accent, dim_fg, 0.40)
  def('ExplorerSearchIcon',         { fg = icon_idle,         bg = search_bg })
  def('ExplorerSearchIconActive',   { fg = accent, bold = true, bg = search_active_bg })

  -- Separator below search row
  def('ExplorerSearchBorder',       { fg = blend(dim_fg, sidebar_bg, 0.55) })
  def('ExplorerSearchBorderActive', { fg = accent })

  -- Text inside the bar
  def('ExplorerSearchPlaceholder',  { fg = blend(dim_fg, sidebar_bg, 0.6), italic = true, bg = search_bg })
  def('ExplorerSearchActiveText',   { fg = str_fg, bold = true })

  -- Match-count badge (right-aligned in the bar)
  def('ExplorerSearchCount',        { fg = blend(accent, dim_fg, 0.5), italic = true })

  -- ── Winbar ────────────────────────────────────────────────────────
  -- Slightly bolder fg for the root name so it pops over the sidebar bg.
  def('ExplorerWinbar',             { bg = sidebar_bg, fg = blend(accent, normal_fg, 0.25) })
  def('ExplorerWinbarBranch',       { bg = sidebar_bg, fg = blend(dim_fg, normal_fg, 0.5), italic = true })

  -- ── Git + marks ───────────────────────────────────────────────────
  git.setup_hl()
  marks.setup_hl()
end

function M.reset_hl()
  local names = {
    'ExplorerNormal', 'ExplorerCursorLine', 'ExplorerDirectory', 'ExplorerConnector',
    'ExplorerSearchBg', 'ExplorerSearchBgActive',
    'ExplorerSearchBorder', 'ExplorerSearchBorderActive',
    'ExplorerSearchIcon', 'ExplorerSearchIconActive',
    'ExplorerSearchPlaceholder', 'ExplorerSearchActiveText', 'ExplorerSearchCount',
    'ExplorerWinbar', 'ExplorerWinbarBranch',
    'ExplorerGitAdded',    'ExplorerGitModified',    'ExplorerGitDeleted',
    'ExplorerGitRenamed',  'ExplorerGitUntracked',   'ExplorerGitConflict',
    'ExplorerGitIgnored',
    'ExplorerGitAddedLine',    'ExplorerGitModifiedLine',  'ExplorerGitDeletedLine',
    'ExplorerGitRenamedLine',  'ExplorerGitUntrackedLine', 'ExplorerGitConflictLine',
    'ExplorerGitIgnoredLine',
    'ExplorerMark',
  }
  for _, name in ipairs(names) do
    pcall(api.nvim_set_hl, 0, name, {})
  end
end

-- ── Buffer ────────────────────────────────────────────────────────────────

function M.make_buf()
  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, buf, 'explorer://')
  local bo = vim.bo[buf]
  bo.buftype    = 'nofile'
  bo.bufhidden  = 'hide'
  bo.buflisted  = false
  bo.filetype   = 'explorer'
  bo.modifiable = false
  bo.swapfile   = false
  bo.omnifunc   = ''
  bo.completefunc = ''
  vim.b[buf].cmp_enabled        = false
  vim.b[buf].completion_enabled = false
  vim.b[buf].completion         = false
  return buf
end

-- ── Window ────────────────────────────────────────────────────────────────

-- Fetch the current git branch synchronously (only called once on open).
local function git_branch(root)
  local r = vim.fn.system('git -C ' .. vim.fn.shellescape(root) .. ' branch --show-current 2>/dev/null')
  r = r:gsub('%s+$', '')
  return (r ~= '' and vim.v.shell_error == 0) and r or nil
end

function M.make_win(buf)
  M.ensure_hl()
  local c    = cfg.get()
  local side = c.side == 'right' and 'botright' or 'topleft'
  vim.cmd(side .. ' ' .. c.width .. 'vsplit')
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)

  local wo = vim.wo[win]
  wo.number         = false
  wo.relativenumber = false
  wo.signcolumn     = 'no'
  wo.winfixwidth    = true
  wo.wrap           = false
  wo.spell          = false
  wo.list           = false
  wo.cursorline     = true
  wo.fillchars      = 'eob: '

  -- Winbar: "  󰉋 root  ⎇ branch"
  -- Built once and stored statically — no %{} expressions that re-eval on
  -- every cursor move, which was the original cause of blinking.
  pcall(function()
    local root   = vim.fn.fnamemodify(S.root or vim.fn.getcwd(), ':t')
    local branch = git_branch(S.root or vim.fn.getcwd())
    local bar    = '%#ExplorerWinbar# 󰉋 ' .. root
    if branch then
      bar = bar .. ' %#ExplorerWinbarBranch#  ' .. branch
    end
    bar = bar .. '%#ExplorerWinbar# '
    wo.winbar = bar
  end)
  pcall(function() wo.statuscolumn = '' end)
  pcall(function() wo.foldcolumn   = '0' end)

  wo.winhl = table.concat({
    'Normal:ExplorerNormal',
    'CursorLine:ExplorerCursorLine',
    'WinBar:ExplorerWinbar',
    'WinBarNC:ExplorerWinbar',
  }, ',')

  S.icon_fn = icons.resolve()
  return win
end

-- ── Update winbar root (called after root changes) ────────────────────────

function M.update_winbar()
  if not (S.win and api.nvim_win_is_valid(S.win)) then return end
  local root   = vim.fn.fnamemodify(S.root or vim.fn.getcwd(), ':t')
  local branch = git_branch(S.root or vim.fn.getcwd())
  pcall(function()
    local bar = '%#ExplorerWinbar# 󰉋 ' .. root
    if branch then
      bar = bar .. ' %#ExplorerWinbarBranch#  ' .. branch
    end
    bar = bar .. '%#ExplorerWinbar# '
    vim.wo[S.win].winbar = bar
  end)
end

-- ── Keymaps ───────────────────────────────────────────────────────────────

function M.setup_keymaps(buf)
  local km = cfg.get().keymaps
  local A  = require 'custom.explorer.actions'
  local opts = { noremap = true, silent = true, nowait = true, buffer = buf }

  local function map(keys, action)
    if type(keys) == 'string' then keys = { keys } end
    for _, k in ipairs(keys) do
      if k and k ~= '' then
        vim.keymap.set('n', k, action, opts)
      end
    end
  end

  map(km.open,          A.open_or_toggle)
  map(km.close_dir,     A.close_dir)
  map(km.go_up,         A.go_up)
  map(km.vsplit,        A.vsplit)
  map(km.split,         A.split)
  map(km.tab,           A.tab_open)
  map(km.add,           A.add)
  map(km.delete,        A.delete)
  map(km.rename,        A.rename)
  map(km.copy,          A.copy)
  map(km.toggle_hidden, A.toggle_hidden)
  map(km.refresh,       A.refresh)
  map(km.copy_path,     A.copy_path)
  map(km.file_info,     A.file_info)
  map(km.mark,          A.toggle_mark)
  map(km.collapse_all,  A.collapse_all)
  map(km.expand_all, function() A.expand_all(1) end)
  map(km.git_stage,     A.git_stage)
  map(km.git_restore,   A.git_restore)
  map(km.help,          A.show_help)
  map(km.search, function()
    require('custom.explorer.search').activate()
  end)
  map(km.quit, function()
    if S.close_fn then S.close_fn() end
  end)
end

return M
