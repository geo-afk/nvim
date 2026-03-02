-- custom/explorer/render.lua
--
-- Buffer layout (1-based lines / 0-based rows):
--
--   Line 1  row 0  │  󰍉  filter files…    ← search bar (always visible)
--   [virt_line]    │  ─────────────────   ← thin separator, NOT a buffer line
--   Line 2  row 1  │  ╰─ 󰢱 init.lua       ← S.items[1]
--   Line 3  row 2  │  ├─ 󰢱 foo.lua        ← S.items[2]
--   …
--
-- Coordinate rules (unchanged):
--   S.items[i]  →  1-based line i+1,  0-based row i
--   cursor row r  →  S.items[r-1]   (valid when r >= 2)
--   git/mark extmark for S.items[i]  →  row i
--
-- Search bar design (single decorated line — no box borders):
--
--   Idle    [bg]  󰍉  filter files…        dim icon, italic placeholder
--           ─────────────────────────     dim separator
--
--   Active  [bg]  󰍉  |cursor              accent icon, cursor inside
--           ─────────────────────────     accent separator
--
--   Filter  [bg]  󰍉  lua                  accent icon, bold filter text
--           ─────────────────────────     dim separator
--
-- Why not a box?
--   virt_lines_above / virt_lines each consume a screen line.  Two borders
--   around a one-line bar pushed tree content down and collided with the
--   inline virt_text width, causing text to overflow the right wall.
--   A single separator virt_line is safe: the cursor never lands on it,
--   and it never displaces tree items.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local tree = require 'custom.explorer.tree'
local git = require 'custom.explorer.git'
local icons = require 'custom.explorer.icons'

local api = vim.api
local M = {}

-- The icon is painted as an OVERLAY on top of ICON_PREFIX spaces.
-- This guarantees the cursor is always to the RIGHT of the icon — it can
-- never land inside col 0..#ICON_PREFIX-1, so the icon never shifts.
--
-- Display width breakdown for '  󰍉  ':
--   2 spaces (2 cols) + 󰍉 glyph (2 cols) + 2 spaces (2 cols) = 6 display cols
-- ICON_PREFIX is 6 plain spaces (6 bytes = 6 cols) — the overlay covers them.
local SEARCH_ICON = '  󰍉  ' -- overlay glyph (6 display cols)
local ICON_PREFIX = '      ' -- 6 spaces written into buffer col 0-5
local PLACEHOLDER = 'filter files…'

-- Exported so search.lua can use the same constant without a magic number.
M.ICON_PREFIX = ICON_PREFIX

-------------------------------------------------------------------------------
-- paint_header: redraws all row-0 extmarks.
--
-- Buffer line 0 always contains:  ICON_PREFIX .. (S.filter or '')
--   e.g. idle+no filter : '      '         (just the 6-space pad)
--        filter set      : '      lua'
--        active typing   : '      lu'  (partial, live)
--
-- The icon is overlaid on top of ICON_PREFIX via virt_text_pos='overlay'.
-- The cursor therefore lives at col >= #ICON_PREFIX at all times.
-------------------------------------------------------------------------------
function M.paint_header()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local is_active = S.search_active
  local has_filter = S.filter and S.filter ~= ''
  local line0 = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''

  local ihl = is_active and 'ExplorerSearchIconActive' or 'ExplorerSearchIcon'
  local shl = is_active and 'ExplorerSearchBorderActive' or 'ExplorerSearchBorder'

  -- ── 1. Background wash ────────────────────────────────────────────────
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = 'ExplorerSearchBg',
    hl_eol = true,
    priority = 5,
  })

  -- ── 2. Icon overlay on top of ICON_PREFIX ────────────────────────────
  -- 'overlay' paints virt_text starting at col 0, covering 6 display cols.
  -- The 6 spaces in the buffer are hidden behind it.  The cursor starts
  -- at col #ICON_PREFIX (= 6) and can never go left of it.
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_text = { { SEARCH_ICON, ihl } },
    virt_text_pos = 'overlay',
    priority = 100,
  })

  -- ── 3. Placeholder — when no filter text and not actively editing ─────
  -- line0 == ICON_PREFIX means the user hasn't typed anything yet.
  if line0 == ICON_PREFIX and not is_active then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, 'ExplorerSearchPlaceholder' } },
      virt_text_pos = 'overlay',
      priority = 50,
    })
  end

  -- ── 4. Active filter highlight (idle with a filter set) ───────────────
  -- Highlights only the filter portion, not the prefix.
  if has_filter and not is_active and #line0 > #ICON_PREFIX then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      end_row = 0,
      end_col = #line0,
      hl_group = 'ExplorerSearchActiveText',
      priority = 60,
    })
  end

  -- ── 5. Separator virt_line below the header ───────────────────────────
  local win_w = cfg.get().width
  if S.win and api.nvim_win_is_valid(S.win) then
    win_w = api.nvim_win_get_width(S.win)
  end
  local sep_char = is_active and '─' or '╌'
  local sep = sep_char:rep(win_w)
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_lines = { { { sep, shl } } },
    priority = 100,
  })
end

-------------------------------------------------------------------------------
-- Debounced full render (tree build + paint)
-------------------------------------------------------------------------------
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
      end)
    )
  end)
end

-------------------------------------------------------------------------------
-- _paint: full synchronous repaint (header + all item lines)
-- Only called when NOT in search mode.
-------------------------------------------------------------------------------
function M._paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  if S.search_active then
    return
  end -- don't overwrite while user is typing

  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  -- Snapshot cursor by file path
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

  -- Build item lines
  local item_lines = {}
  local hls = {}

  for _, item in ipairs(S.items) do
    local prefix = ''
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = 'ExplorerDirectory'
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. ' '

    local sign_ph = '  '
    local name_col = #sign_ph + #prefix + #icon
    local line = sign_ph .. prefix .. icon .. item.name

    item_lines[#item_lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    -- 0-based row = index into S.items (row 0 = header, so item i is at row i)
    local row = #item_lines -- = i (1-based index of this item)
    local c0 = #sign_ph
    local c1 = c0 + #prefix

    hls[#hls + 1] = { row, c0, c1, 'ExplorerConnector' }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c1 + #icon, icon_hl }
    end
    hls[#hls + 1] = { row, name_col, name_col + #item.name, item.is_dir and 'ExplorerDirectory' or 'Normal' }
  end

  -- Write buffer: line 1 = ICON_PREFIX + filter text, lines 2+ = items
  -- ICON_PREFIX is always present so the overlay icon has space to sit on.
  local header_text = ICON_PREFIX .. (S.filter or '')
  local all_lines = { header_text }
  vim.list_extend(all_lines, item_lines)

  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    -- h[1] is 1-based item index; 0-based row = h[1] (header is row 0, item 1 is row 1)
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

-------------------------------------------------------------------------------
-- _paint_items_only: rewrite only lines 2+ (called live while user types in
-- the search bar, so line 1 is left untouched while insert mode is active)
-------------------------------------------------------------------------------
function M._paint_items_only()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  local item_lines = {}
  local hls = {}

  for _, item in ipairs(S.items) do
    local prefix = ''
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = 'ExplorerDirectory'
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. ' '

    local sign_ph = '  '
    local name_col = #sign_ph + #prefix + #icon
    local line = sign_ph .. prefix .. icon .. item.name

    item_lines[#item_lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    local row = #item_lines
    local c0 = #sign_ph
    local c1 = c0 + #prefix
    hls[#hls + 1] = { row, c0, c1, 'ExplorerConnector' }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c1 + #icon, icon_hl }
    end
    hls[#hls + 1] = { row, name_col, name_col + #item.name, item.is_dir and 'ExplorerDirectory' or 'Normal' }
  end

  -- Rewrite only from line index 1 onward (0-indexed = lines 2+ in 1-based).
  -- We manage modifiable ourselves so this is safe regardless of what other
  -- plugins may have done to the buffer options between the typing event and
  -- this scheduled callback firing.
  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 1, -1, false, item_lines)

  -- Clear only item highlights (not header namespace)
  api.nvim_buf_clear_namespace(buf, S.ns, 1, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_add_highlight, buf, S.ns, h[4], h[1], h[2], h[3])
  end

  -- CRITICAL: do NOT lock the buffer if the user is still typing in the
  -- search bar (insert mode, line 1).  Locking here is what produces
  -- "E21: Cannot make changes, 'modifiable' is off" on the very next keypress.
  -- The buffer will be locked again by deactivate() when InsertLeave fires.
  if not S.search_active then
    api.nvim_buf_set_option(buf, 'modifiable', false)
  end

  git.apply()
end

return M
