-- custom/explorer/search.lua
--
-- The search bar IS buffer line 1 — always visible, no floating windows.
--
-- Buffer line 0 always contains:  ICON_PREFIX .. (filter_text or '')
-- The icon is painted as an extmark OVERLAY on top of ICON_PREFIX, so it
-- is always anchored to the left and the cursor can never move into it.
--
-- Keymaps (insert mode, only while search_active):
--   <CR>      confirm and exit insert (keeps filter)
--   <Esc>     clear filter and exit insert
--   <C-u>     wipe filter text, stay in insert
--   <BS>      blocked when cursor is at or before the icon boundary
--   <Home>    jump to start of filter text (col #ICON_PREFIX)
--   <C-a>     same as <Home>
--   completion keys → all <Nop> to prevent popup bleed

local S      = require 'custom.explorer.state'
local render = require 'custom.explorer.render'
local tree   = require 'custom.explorer.tree'
local api    = vim.api

-- Mirror the constant from render so we never hard-code the prefix width.
local ICON_PREFIX = render.ICON_PREFIX

local M = {}
local _rebuild_scheduled = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local function strip_prefix(raw)
  if raw:sub(1, #ICON_PREFIX) == ICON_PREFIX then
    return raw:sub(#ICON_PREFIX + 1)
  end
  return raw
end

local function rebuild_items()
  if _rebuild_scheduled then return end
  _rebuild_scheduled = true
  S.build_tok = S.build_tok + 1
  local tok   = S.build_tok
  vim.schedule(function()
    _rebuild_scheduled = false
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then return end
    tree.build(
      tok,
      S.filter,
      vim.schedule_wrap(function(items)
        if S.build_tok ~= tok then return end
        S.items = items
        render._paint_items_only()
        -- Refresh the header so the count badge updates live
        render.paint_header()
      end)
    )
  end)
end

local function kill_completion(buf)
  vim.b[buf].completion         = false
  vim.b[buf].blink_cmp_enabled  = false
  vim.b[buf].cmp_enabled        = false
  vim.b[buf].coq_settings       = { completion = { enabled = false } }
  vim.b[buf].completion_enabled = false
  pcall(function() vim.bo[buf].omnifunc   = '' end)
  pcall(function() vim.bo[buf].completefunc = '' end)
end

local function restore_completion(buf)
  vim.b[buf].completion         = nil
  vim.b[buf].blink_cmp_enabled  = nil
  vim.b[buf].cmp_enabled        = nil
  vim.b[buf].coq_settings       = nil
  vim.b[buf].completion_enabled = nil
  local ok, blink = pcall(require, 'blink.cmp')
  if ok and type(blink.enable) == 'function' then
    pcall(blink.enable, buf)
  end
end

-- ── activate ──────────────────────────────────────────────────────────────

function M.activate()
  if not (S.buf and api.nvim_buf_is_valid(S.buf))   then return end
  if not (S.win and api.nvim_win_is_valid(S.win))   then return end

  -- If already active, just move the cursor to the end of the filter text
  if S.search_active then
    local col = #ICON_PREFIX + #(S.filter or '')
    api.nvim_win_set_cursor(S.win, { 1, col })
    vim.cmd 'startinsert!'
    return
  end

  S.search_active = true
  kill_completion(S.buf)

  local filter_text = S.filter or ''
  local line_text   = ICON_PREFIX .. filter_text

  api.nvim_buf_set_option(S.buf, 'modifiable', true)
  api.nvim_buf_set_lines(S.buf, 0, 1, false, { line_text })

  -- paint_header picks up search_active=true and switches to the active bg/icon
  render.paint_header()

  api.nvim_win_set_cursor(S.win, { 1, #line_text })
  vim.cmd 'startinsert!'
end

-- ── deactivate (internal) ─────────────────────────────────────────────────

local function deactivate(clear_filter)
  if not S.search_active then return end
  S.search_active = false

  local raw  = (S.buf and api.nvim_buf_is_valid(S.buf))
               and (api.nvim_buf_get_lines(S.buf, 0, 1, false)[1] or '')
               or ''
  local text = strip_prefix(raw)

  S.filter = (not clear_filter and text ~= '') and text or nil

  restore_completion(S.buf)

  if S.buf and api.nvim_buf_is_valid(S.buf) then
    api.nvim_buf_set_option(S.buf, 'modifiable', false)
  end

  render.render()

  vim.schedule(function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then return end
    if #S.items == 0 then return end
    if api.nvim_win_get_cursor(S.win)[1] < 2 then
      api.nvim_win_set_cursor(S.win, { 2, 0 })
    end
  end)
end

-- ── setup: attach autocmds and buffer-local keymaps ──────────────────────

function M.setup(buf)
  local bopts = { buffer = buf, silent = true, noremap = true }

  -- Prevent the cursor from resting on the search bar row (row 0) in normal mode
  api.nvim_create_autocmd('CursorMoved', {
    buffer   = buf,
    callback = function()
      if S.search_active then return end
      if not (S.win and api.nvim_win_is_valid(S.win)) then return end
      if api.nvim_win_get_cursor(S.win)[1] == 1 then
        pcall(api.nvim_win_set_cursor, S.win, {
          math.max(2, #S.items > 0 and 2 or 1), 0
        })
      end
    end,
  })

  -- Live-filter: rebuild the tree on every keystroke in the search bar
  api.nvim_create_autocmd('TextChangedI', {
    buffer   = buf,
    callback = function()
      if not S.search_active then return end
      if api.nvim_win_get_cursor(S.win)[1] ~= 1 then return end
      local raw = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
      local t   = strip_prefix(raw)
      S.filter  = t ~= '' and t or nil
      rebuild_items()
    end,
  })

  -- InsertLeave: commit or discard the filter
  api.nvim_create_autocmd('InsertLeave', {
    buffer   = buf,
    callback = vim.schedule_wrap(function()
      if not S.search_active then return end
      deactivate(S._search_clear_on_leave)
      S._search_clear_on_leave = false
    end),
  })

  -- Block completion popups
  for _, k in ipairs {
    '<C-n>', '<C-p>',
    '<C-x><C-o>', '<C-x><C-n>', '<C-x><C-p>', '<C-x><C-f>',
    '<C-x><C-l>', '<C-x><C-s>', '<C-x><C-k>',
    '<Tab>', '<S-Tab>', '<C-y>', '<C-e>',
  } do
    vim.keymap.set('i', k, '<Nop>', bopts)
  end

  -- <CR>: confirm (keep filter)
  vim.keymap.set('i', '<CR>', function()
    if not S.search_active then return end
    S._search_clear_on_leave = false
    vim.cmd 'stopinsert'
  end, bopts)

  -- <Esc>: discard filter
  vim.keymap.set('i', '<Esc>', function()
    if not S.search_active then return end
    S._search_clear_on_leave = true
    vim.cmd 'stopinsert'
  end, bopts)

  -- <C-u>: wipe filter text but stay in insert
  vim.keymap.set('i', '<C-u>', function()
    if not S.search_active then return end
    api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
    S.filter = nil
    api.nvim_win_set_cursor(S.win, { 1, #ICON_PREFIX })
    render.paint_header()
    rebuild_items()
  end, bopts)

  -- <BS>: block deletion into the icon prefix zone
  vim.keymap.set('i', '<BS>', function()
    if not S.search_active then return '<BS>' end
    local col = api.nvim_win_get_cursor(S.win)[2]
    if col <= #ICON_PREFIX then return '' end
    return '<BS>'
  end, { buffer = buf, silent = true, noremap = true, expr = true })

  -- <Home> / <C-a>: jump to start of filter text (not col 0)
  local function to_filter_start()
    if not S.search_active then return end
    api.nvim_win_set_cursor(S.win, { 1, #ICON_PREFIX })
  end
  vim.keymap.set('i', '<Home>', to_filter_start, bopts)
  vim.keymap.set('i', '<C-a>', to_filter_start, bopts)
end

-- ── close / clear (called externally) ────────────────────────────────────

function M.close()
  if S.search_active then
    S.search_active = false
    if S.buf and api.nvim_buf_is_valid(S.buf) then
      pcall(api.nvim_buf_set_option, S.buf, 'modifiable', false)
    end
  end
end

function M.clear()
  S.filter        = nil
  S.search_active = false
  if S.buf and api.nvim_buf_is_valid(S.buf) then
    pcall(api.nvim_buf_set_option, S.buf, 'modifiable', false)
  end
  render.render()
end

return M
