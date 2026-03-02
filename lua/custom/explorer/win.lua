-- custom/explorer/win.lua
-- Window creation, highlight groups, keymaps.
-- NO dynamic winbar expression — that caused constant redraws/blinking.
-- The search bar lives in a floating window (see search.lua), not the winbar
-- or a buffer line.  Line 1 of the tree buffer is a read-only status strip.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local git = require 'custom.explorer.git'
local marks = require 'custom.explorer.marks'
local icons = require 'custom.explorer.icons'
local api = vim.api

local M = {}

-- ── Sakura fallback palette ───────────────────────────────────────────────
local PAL = {
  sakura = 0xffb3c6,
  lilac = 0xc3aed6,
  sky = 0x8bc6fc,
  mint = 0xa8e6cf,
  peach = 0xffcb8e,
  rose = 0xff6b9d,
  mist = 0x7a8899,
  deep = 0x1e2030,
}

-- ── Helpers ───────────────────────────────────────────────────────────────

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
    if h.fg then
      return h.fg
    end
  end
end

local function bg_of(...)
  for _, n in ipairs { ... } do
    local h = get(n)
    if h.bg then
      return h.bg
    end
  end
end

-- Blend two hex colours at ratio a (0 = all bg, 1 = all fg)
local function blend(fg, bg, a)
  local function lerp(f, b)
    return math.floor(f * a + b * (1 - a) + 0.5)
  end
  local function ch(c, shift)
    return math.floor(c / shift) % 0x100
  end
  return lerp(ch(fg, 0x10000), ch(bg, 0x10000)) * 0x10000 + lerp(ch(fg, 0x100), ch(bg, 0x100)) * 0x100 + lerp(ch(fg, 1), ch(bg, 1))
end

-- ── Highlights ────────────────────────────────────────────────────────────

function M.ensure_hl()
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = 'ExplorerNormal' })
  if ok and ex and next(ex) then
    return
  end

  local normal = get 'Normal'
  local float_ = get 'NormalFloat'
  local cursor = get 'CursorLine'
  local comment = get 'Comment'

  local sidebar_bg = float_.bg or bg_of('NormalFloat', 'Normal') or PAL.deep
  local dim_fg = comment.fg or PAL.mist
  local accent = fg_of('Function', 'Special', 'Statement', '@function') or PAL.sakura
  local dir_fg = fg_of('Directory', '@constructor') or PAL.lilac
  local string_fg = fg_of('String', '@string') or PAL.mint

  -- ── Core sidebar ──────────────────────────────────────────────────────
  def('ExplorerNormal', { bg = sidebar_bg, fg = normal.fg })
  def('ExplorerCursorLine', { bg = cursor.bg or 'NONE', bold = true })
  def('ExplorerDirectory', { fg = dir_fg, bold = true })
  def('ExplorerConnector', { fg = dim_fg })

  -- ── Inline search bar (row 0) ─────────────────────────────────────────
  --
  --   Idle    [bg]  󰍉  filter files…        dim icon, italic placeholder
  --           ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌   dim dashed separator
  --
  --   Active  [bg]  󰍉  |cursor              accent icon + solid separator
  --
  --   Filter  [bg]  󰍉  lua                  accent icon, bold text, dim sep

  -- Background: identical to sidebar so the bar blends in seamlessly
  def('ExplorerSearchBg', { bg = sidebar_bg, fg = normal.fg })

  -- Icon: dim when idle, accent when active or filter set
  local icon_dim = blend(accent, dim_fg, 0.30)
  def('ExplorerSearchIcon', { fg = icon_dim })
  def('ExplorerSearchIconActive', { fg = accent, bold = true })

  -- Separator line: dim dashed when idle, accent solid when active
  def('ExplorerSearchBorder', { fg = blend(dim_fg, sidebar_bg, 0.60) })
  def('ExplorerSearchBorderActive', { fg = accent })

  -- Placeholder and active-filter text
  def('ExplorerSearchPlaceholder', { fg = dim_fg, italic = true })
  def('ExplorerSearchActiveText', { fg = string_fg, bold = true })

  -- ── Winbar ────────────────────────────────────────────────────────────
  def('ExplorerWinbar', { bg = sidebar_bg, fg = dim_fg, bold = false })

  -- ── Git + marks ───────────────────────────────────────────────────────
  git.setup_hl()
  marks.setup_hl()
end

function M.reset_hl()
  local names = {
    'ExplorerNormal',
    'ExplorerCursorLine',
    'ExplorerDirectory',
    'ExplorerConnector',
    -- Search box (inline, row 0)
    'ExplorerSearchBg',
    'ExplorerSearchBorder',
    'ExplorerSearchBorderActive',
    'ExplorerSearchIcon',
    'ExplorerSearchIconActive',
    'ExplorerSearchPlaceholder',
    'ExplorerSearchActiveText',
    -- Winbar
    'ExplorerWinbar',
    -- Git
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
    -- Marks
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
  bo.buftype = 'nofile'
  bo.bufhidden = 'hide'
  bo.buflisted = false
  bo.filetype = 'explorer'
  bo.modifiable = false
  bo.swapfile = false
  -- Kill all completion sources on the tree buffer too
  bo.omnifunc = ''
  bo.completefunc = ''
  vim.b[buf].cmp_enabled = false
  vim.b[buf].completion_enabled = false
  vim.b[buf].completion = false
  return buf
end

-- ── Window ────────────────────────────────────────────────────────────────

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

  -- Static winbar: just the folder icon + root name.
  -- NO %{%v:lua...%} expression — that re-evaluates on every cursor move
  -- and was the original cause of blinking/flicker.
  pcall(function()
    local root = vim.fn.fnamemodify(S.root or vim.fn.getcwd(), ':t')
    wo.winbar = '%#ExplorerWinbar#  󰉋  ' .. root .. ' '
  end)
  pcall(function()
    wo.statuscolumn = ''
  end)
  pcall(function()
    wo.foldcolumn = '0'
  end)

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
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  local root = vim.fn.fnamemodify(S.root or vim.fn.getcwd(), ':t')
  pcall(function()
    vim.wo[S.win].winbar = '%#ExplorerWinbar#  󰉋  ' .. root .. ' '
  end)
end

-- ── Keymaps ───────────────────────────────────────────────────────────────

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
  map(km.search, function()
    require('custom.explorer.search').activate()
  end)
  map(km.quit, function()
    if S.close_fn then
      S.close_fn()
    end
  end)
end

return M
