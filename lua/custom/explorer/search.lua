-- explorer/search.lua
--
-- Permanent always-visible search bar — a 1-line floating window anchored
-- at the very top of the explorer sidebar.
--
-- Visual anatomy (what the user sees):
--
--   ┌────────────────────────────────┐  ← search float (height=1)
--   │  󰔎  Search...                 │     inactive: dim placeholder
--   │  󰔎  foo█                      │     active:   icon + typed text
--   ├────────────────────────────────┤  ← separator (buffer line 2)
--   │  ├  󰢱  init.lua               │  ← tree items (buffer line 3+)
--   └────────────────────────────────┘
--
-- State machine:
--   tree normal  ──  /  ──►  search insert (activate)
--   search insert ─── <CR>  ──►  keep filter, return to tree
--   search insert ─── <Esc> ──►  clear filter, return to tree
--   search insert ─── InsertLeave (any) ──►  return to tree  (auto)

local S = require 'custom.explorer.state'
local render = require 'custom.explorer.render'
local api = vim.api

local M = {}

local NS = api.nvim_create_namespace 'explorer_search'
local ICON_STR = '  󰔎  ' -- left pad + magnifier + right gap
local HOLDER = 'Search...'

-------------------------------------------------------------------------------
-- Highlight setup
-------------------------------------------------------------------------------
function M.setup_hl()
  local function get(n)
    local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
    return ok and h or {}
  end
  local function def(n, o)
    pcall(api.nvim_set_hl, 0, n, o)
  end

  local normal = get 'Normal'
  local float_ = get 'NormalFloat'
  local comment = get 'Comment'
  local pmenu = get 'Pmenu'

  local bar_bg = pmenu.bg or float_.bg or normal.bg
  local accent = get('Function').fg or get('Special').fg or get('Statement').fg or 0x7aa2f7
  local dim_fg = comment.fg or 0x565f89

  def('ExplorerSearchBar', { bg = bar_bg, fg = normal.fg })
  def('ExplorerSearchIcon', { bg = bar_bg, fg = accent, bold = true })
  def('ExplorerSearchPlaceholder', { bg = bar_bg, fg = dim_fg, italic = true })
  def('ExplorerSeparator', { fg = dim_fg, bg = get('ExplorerNormal').bg })
end

-------------------------------------------------------------------------------
-- repaint_bar: refresh virt-text decorations (icon + optional placeholder)
-------------------------------------------------------------------------------
local function repaint_bar()
  local ibuf = S.search_buf
  if not (ibuf and api.nvim_buf_is_valid(ibuf)) then
    return
  end
  api.nvim_buf_clear_namespace(ibuf, NS, 0, -1)

  -- Icon: "inline" inserts before real text without consuming buffer bytes.
  -- (Requires nvim ≥ 0.10; the user already uses vim.uv which implies 0.10+)
  pcall(api.nvim_buf_set_extmark, ibuf, NS, 0, 0, {
    virt_text = { { ICON_STR, 'ExplorerSearchIcon' } },
    virt_text_pos = 'inline',
    priority = 200,
  })

  -- Placeholder: only when the line is empty
  local line = api.nvim_buf_get_lines(ibuf, 0, 1, false)[1] or ''
  if line == '' then
    pcall(api.nvim_buf_set_extmark, ibuf, NS, 0, 0, {
      virt_text = { { HOLDER, 'ExplorerSearchPlaceholder' } },
      virt_text_pos = 'eol',
      priority = 10,
    })
  end
end

-------------------------------------------------------------------------------
-- ensure_bar: create the permanent floating bar (idempotent)
-- Called from init.open() whenever the explorer window is created.
-------------------------------------------------------------------------------
function M.ensure_bar()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end

  -- Already alive — just repaint decorations
  if S.search_win and api.nvim_win_is_valid(S.search_win) then
    repaint_bar()
    return
  end

  -- 1. Create a writable scratch buffer (holds search text only, not the icon)
  local ibuf = api.nvim_create_buf(false, true)
  vim.bo[ibuf].buftype = 'nofile'
  vim.bo[ibuf].buflisted = false
  vim.bo[ibuf].filetype = 'explorer_search'
  vim.bo[ibuf].modifiable = true
  vim.bo[ibuf].swapfile = false

  -- Restore any surviving filter from a previous open
  if S.filter and S.filter ~= '' then
    api.nvim_buf_set_lines(ibuf, 0, -1, false, { S.filter })
  end

  -- 2. Float: flush with top-left of the explorer, no border, no padding
  local win_w = api.nvim_win_get_width(S.win)
  local swin = api.nvim_open_win(ibuf, false, {
    relative = 'win',
    win = S.win,
    row = 0,
    col = 0,
    width = win_w,
    height = 1,
    style = 'minimal',
    focusable = true,
    zindex = 50,
  })

  vim.wo[swin].winhl = 'Normal:ExplorerSearchBar,CursorLine:ExplorerSearchBar,NormalFloat:ExplorerSearchBar'
  pcall(function()
    vim.wo[swin].winbar = ''
  end)
  pcall(function()
    vim.wo[swin].statuscolumn = ''
  end)
  pcall(function()
    vim.wo[swin].cursorline = false
  end)

  S.search_win = swin
  S.search_buf = ibuf

  -- 3. Live filter: fires on every keystroke
  api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
    buffer = ibuf,
    callback = function()
      local t = api.nvim_buf_get_lines(ibuf, 0, 1, false)[1] or ''
      S.filter = t ~= '' and t or nil
      repaint_bar()
      render.render()
    end,
  })

  -- 4. Auto-return to tree when insert mode ends, whatever the cause.
  --    vim.schedule delays one tick so keymap handlers (<CR>, <Esc>) run first.
  api.nvim_create_autocmd('InsertLeave', {
    buffer = ibuf,
    callback = vim.schedule_wrap(function()
      -- Only redirect if we're still sitting in the search float
      if api.nvim_get_current_win() == swin and S.win and api.nvim_win_is_valid(S.win) then
        api.nvim_set_current_win(S.win)
      end
    end),
  })

  -- 5. Keymaps
  local bopts = { buffer = ibuf, silent = true, noremap = true }

  vim.keymap.set({ 'i', 'n' }, '<CR>', function()
    -- Confirm: keep filter, leave insert → InsertLeave handles focus return
    local t = api.nvim_buf_get_lines(ibuf, 0, 1, false)[1] or ''
    S.filter = t ~= '' and t or nil
    vim.cmd 'stopinsert'
  end, bopts)

  vim.keymap.set({ 'i', 'n' }, '<Esc>', function()
    -- Cancel: clear filter, leave insert → InsertLeave handles focus return
    S.filter = nil
    api.nvim_buf_set_lines(ibuf, 0, -1, false, { '' })
    repaint_bar()
    render.render()
    vim.cmd 'stopinsert'
  end, bopts)

  vim.keymap.set('i', '<C-u>', function()
    -- Clear text but stay in insert mode
    api.nvim_buf_set_lines(ibuf, 0, -1, false, { '' })
    S.filter = nil
    repaint_bar()
    render.render()
  end, bopts)

  -- 6. State cleanup if float is closed externally (e.g. :bdelete)
  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(swin),
    once = true,
    callback = function()
      if S.search_win == swin then
        S.search_win = nil
        S.search_buf = nil
      end
    end,
  })

  repaint_bar()
end

-------------------------------------------------------------------------------
-- activate: focus the bar and enter insert mode (called by "/" keymap)
-------------------------------------------------------------------------------
function M.activate()
  M.ensure_bar()
  local swin = S.search_win
  if not (swin and api.nvim_win_is_valid(swin)) then
    return
  end
  api.nvim_set_current_win(swin)
  local text = ''
  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    text = api.nvim_buf_get_lines(S.search_buf, 0, 1, false)[1] or ''
  end
  -- Put cursor after existing text (visual end = after icon + text)
  pcall(api.nvim_win_set_cursor, swin, { 1, #text })
  vim.cmd 'startinsert!'
end

-------------------------------------------------------------------------------
-- resize: called when the explorer window is resized
-------------------------------------------------------------------------------
function M.resize()
  local swin = S.search_win
  local ewin = S.win
  if not (swin and api.nvim_win_is_valid(swin)) then
    return
  end
  if not (ewin and api.nvim_win_is_valid(ewin)) then
    return
  end
  pcall(api.nvim_win_set_config, swin, {
    relative = 'win',
    win = ewin,
    width = api.nvim_win_get_width(ewin),
    row = 0,
    col = 0,
  })
end

-------------------------------------------------------------------------------
-- close / clear
-------------------------------------------------------------------------------
function M.close()
  if S.search_win and api.nvim_win_is_valid(S.search_win) then
    pcall(api.nvim_win_close, S.search_win, true)
  end
  S.search_win = nil
  S.search_buf = nil
end

function M.clear()
  S.filter = nil
  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    api.nvim_buf_set_lines(S.search_buf, 0, -1, false, { '' })
    -- Trigger repaint via the TextChanged autocmd path
    local ok_ns = api.nvim_create_namespace 'explorer_search'
    api.nvim_buf_clear_namespace(S.search_buf, ok_ns, 0, -1)
    -- Directly call repaint since TextChanged won't fire for programmatic edits
    repaint_bar()
  end
  render.render()
end

return M
