-- custom/explorer/render.lua
--
-- Buffer layout (1-based lines / 0-based rows):
--
--   Line 1  row 0  │   󰍉  filter files…     ← search bar (always visible)
--   [virt_line]    │  ──────────────────    ← separator (not a real line)
--   Line 2  row 1  │  ╰─ 󰢱 init.lua        ← S.items[1]
--   Line 3  row 2  │  ├─ 󰢱 foo.lua         ← S.items[2]
--   …
--
-- Coordinate rules (unchanged):
--   S.items[i]  →  1-based line i+1,  0-based row i
--   cursor row r  →  S.items[r-1]   (valid when r >= 2)
--   git/mark extmark for S.items[i]  →  row i
--
-- ── Search bar visual states ──────────────────────────────────────────────
--
--  IDLE / empty   ░░ 󰍉 filter files…                    ░░
--                 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
--                 (muted icon; italic placeholder; dashed sep)
--
--  FILTER SET     ▓▓ 󰍉 lua                      3 of 9 ▓▓
--                 ──────────────────────────────────────────
--                 (accent icon; bold filter text; count badge; solid sep)
--
--  ACTIVE         ▓▓ 󰍉 lua█                             ▓▓
--                 ══════════════════════════════════════════
--                 (bright bg; accent icon; cursor; accent sep)
--
-- Why no box-drawing borders?
--   virt_lines_above consume a screen line each.  Two borders around a
--   one-line bar pushed tree content down and caused extmark width collisions.
--   A single separator virt_line is safe — the cursor never lands on it.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local tree = require 'custom.explorer.tree'
local git = require 'custom.explorer.git'
local icons = require 'custom.explorer.icons'

local api = vim.api
local M = {}

-- ── Search bar constants ───────────────────────────────────────────────────
--
-- The icon is painted as an OVERLAY on top of ICON_PREFIX spaces, keeping
-- the cursor permanently to the right of the icon glyph.
--
-- Display layout:  ' 󰍉  '  = 1 sp + icon(2 cols) + 2 sp = 5 display cols
-- ICON_PREFIX      = 5 plain spaces (one per display col of the overlay)
--
local SEARCH_ICON = ' 󰍉  ' -- overlay (5 display cols)
local ICON_PREFIX = '     ' -- 5 spaces written into the buffer (col 0-4)
local PLACEHOLDER = 'filter files…'

-- Exported so search.lua can mirror the constant.
M.ICON_PREFIX = ICON_PREFIX

-- ── paint_header ──────────────────────────────────────────────────────────
--
-- Redraws all row-0 extmarks.  Buffer line 0 always contains:
--   ICON_PREFIX .. (S.filter or '')
--
-- Three visual zones painted via extmarks:
--   1. Background wash   — full row, low priority
--   2. Icon overlay      — col 0, covers ICON_PREFIX
--   3a. Placeholder      — shown when buffer text == ICON_PREFIX and idle
--   3b. Filter highlight — shown when filter is set and idle
--   4. Count badge       — right-aligned, shown when filter set and idle
--   5. Separator         — virt_line below the header row

function M.paint_header()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local is_active = S.search_active
  local has_filter = S.filter and S.filter ~= ''
  local line0 = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''

  -- Choose highlight groups for current state
  local bg_hl = is_active and 'ExplorerSearchBgActive' or 'ExplorerSearchBg'
  local ico_hl = is_active and 'ExplorerSearchIconActive' or 'ExplorerSearchIcon'
  local sep_hl = is_active and 'ExplorerSearchBorderActive' or 'ExplorerSearchBorder'

  -- 1. Background wash ─────────────────────────────────────────────────────
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = bg_hl,
    hl_eol = true,
    priority = 5,
  })

  -- 2. Icon overlay ─────────────────────────────────────────────────────────
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_text = { { SEARCH_ICON, ico_hl } },
    virt_text_pos = 'overlay',
    priority = 100,
  })

  -- 3a. Placeholder (idle, no filter) ──────────────────────────────────────
  if line0 == ICON_PREFIX and not is_active then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, 'ExplorerSearchPlaceholder' } },
      virt_text_pos = 'overlay',
      priority = 50,
    })
  end

  -- 3b. Filter text highlight (has filter, not actively typing) ────────────
  if has_filter and not is_active and #line0 > #ICON_PREFIX then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      end_row = 0,
      end_col = #line0,
      hl_group = 'ExplorerSearchActiveText',
      priority = 60,
    })
  end

  -- 4. Match-count badge (right-aligned, filter set, idle) ─────────────────
  if has_filter and not is_active and cfg.get().search_count then
    local total = #S.items
    local label = total == 0 and ' no matches ' or (' ' .. total .. (total == 1 and ' match ' or ' matches '))
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
      virt_text = { { label, 'ExplorerSearchCount' } },
      virt_text_pos = 'right_align',
      priority = 70,
    })
  end

  -- 5. Separator virt_line ──────────────────────────────────────────────────
  -- Active state uses a solid double-width dash to feel more emphatic.
  -- Idle uses very faint dashes.  Filter-set uses solid but muted.
  local win_w = cfg.get().width
  if S.win and api.nvim_win_is_valid(S.win) then
    win_w = api.nvim_win_get_width(S.win)
  end

  local sep_char = is_active and '─' or (has_filter and '─' or '╌')
  local sep = sep_char:rep(win_w)

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_lines = { { { sep, sep_hl } } },
    priority = 100,
  })
end

-- ── _reveal_cursor ────────────────────────────────────────────────────────
--
-- Move the explorer cursor to `path` and center the viewport (zz).
-- Called after every build that has S._reveal_target set.
-- Uses nvim_win_call so it works even when the explorer is not the focused window.

function M._reveal_cursor(path)
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  for i, it in ipairs(S.items) do
    if it.path == path then
      local target_row = i + 1 -- 1-based line (header = line 1, items start at line 2)
      pcall(api.nvim_win_set_cursor, S.win, { target_row, 0 })
      -- Center the revealed line so there is context above and below.
      -- nvim_win_call temporarily switches to the window and executes the
      -- command without changing which window the user has focused.
      pcall(api.nvim_win_call, S.win, function()
        vim.cmd 'normal! zz'
      end)
      return
    end
  end
  -- File not found in current tree (e.g. filtered out) — silently ignore.
end

-- ── Debounced full render (tree build + paint) ────────────────────────────
--
-- This is the single shared build entry point.  reveal() registers a
-- S._reveal_target and calls render() — the two never start competing builds.

local _scheduled = false

function M.render()
  if _scheduled then
    return
  end
  _scheduled = true
  S.build_tok = S.build_tok + 1
  local tok = S.build_tok

  vim.schedule(function()
    _scheduled = false
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
      return
    end
    tree.build(
      tok,
      S.filter,
      vim.schedule_wrap(function(items)
        if S.build_tok ~= tok then
          return
        end
        S.items = items
        M._paint()
        git.apply()
        -- Post-build: move cursor to reveal target if one is pending.
        -- We consume the target here so concurrent renders don't double-jump.
        local target = S._reveal_target
        if target then
          S._reveal_target = nil
          M._reveal_cursor(target)
        end
      end)
    )
  end)
end

-- ── _build_item_lines: shared helper ─────────────────────────────────────

local function build_item_lines()
  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  local lines = {}
  local hls = {}

  for _, item in ipairs(S.items) do
    -- Tree connector prefix
    local prefix = ''
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    -- Icon
    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = 'ExplorerDirectory'
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. ' '

    -- Column positions
    local sign_ph = '  ' -- 2-col placeholder for git/mark sign
    local name_col = #sign_ph + #prefix + #icon
    local line = sign_ph .. prefix .. icon .. item.name

    lines[#lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    -- 0-based row = index into S.items (header = row 0, item i = row i)
    local row = #lines
    local c0 = #sign_ph
    local c1 = c0 + #prefix

    hls[#hls + 1] = { row, c0, c1, 'ExplorerConnector' }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c1 + #icon, icon_hl }
    end
    hls[#hls + 1] = {
      row,
      name_col,
      name_col + #item.name,
      item.is_dir and 'ExplorerDirectory' or 'Normal',
    }
  end

  return lines, hls
end

-- ── _paint: full synchronous repaint (header + all item lines) ───────────

function M._paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  if S.search_active then
    return
  end -- don't overwrite while user is typing

  -- Snapshot cursor position by file path
  local cursor_path
  if S.win and api.nvim_win_is_valid(S.win) then
    local r = api.nvim_win_get_cursor(S.win)[1]
    if r >= 2 then
      local it = S.items[r - 1]
      if it then
        cursor_path = it.path
      end
    end
  end

  local item_lines, hls = build_item_lines()

  -- Assemble full buffer: header line + item lines
  local header_text = ICON_PREFIX .. (S.filter or '')
  local all_lines = { header_text }
  vim.list_extend(all_lines, item_lines)

  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    -- h[1] is 1-based item index; 0-based row = h[1]
    pcall(api.nvim_buf_add_highlight, buf, S.ns, h[4], h[1], h[2], h[3])
  end
  api.nvim_buf_set_option(buf, 'modifiable', false)

  M.paint_header()

  -- Restore cursor
  if S.win and api.nvim_win_is_valid(S.win) then
    local target
    if cursor_path then
      for i, item in ipairs(S.items) do
        if item.path == cursor_path then
          target = i + 1
          break
        end
      end
    end
    local total = #all_lines
    if total < 2 then
      return
    end
    local cur = api.nvim_win_get_cursor(S.win)[1]
    local row = target and math.min(target, total) or math.max(2, math.min(cur, total))
    pcall(api.nvim_win_set_cursor, S.win, { row, 0 })
  end
end

-- ── _paint_items_only: rewrite only lines 2+ (live search updates) ────────
--
-- Called while the user is typing in the search bar.  Line 1 (the search
-- bar itself) must NOT be rewritten — insert mode is still active there.

function M._paint_items_only()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local item_lines, hls = build_item_lines()

  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 1, -1, false, item_lines)

  api.nvim_buf_clear_namespace(buf, S.ns, 1, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_add_highlight, buf, S.ns, h[4], h[1], h[2], h[3])
  end

  -- CRITICAL: do NOT lock the buffer if the user is still typing.
  -- The buffer is re-locked by deactivate() when InsertLeave fires.
  if not S.search_active then
    api.nvim_buf_set_option(buf, 'modifiable', false)
  end

  git.apply()
end

return M
