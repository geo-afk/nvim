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
-- Coordinate rules:
--   S.items[i]  →  1-based line i+1,  0-based row i
--   cursor row r  →  S.items[r-1]   (valid when r >= 2)
--   git/mark extmark for S.items[i]  →  row i
--
-- Sign column (cols 0-1 of every item row):
--   Always written as two spaces ("  ") in the buffer text.
--   Overlaid by git.lua (priority 20) or marks.lua (priority 30).
--   Marks win over git signs when both are present.
--   The 2-col width is a constant shared with git.lua via SIGN_PH_WIDTH.
--
-- ── Search bar visual states ──────────────────────────────────────────────
--
--  IDLE / empty   ░░ 󰍉 filter files…                    ░░
--                 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  (dashed)
--
--  FILTER SET     ▓▓ 󰍉 lua                      3 matches ▓▓
--                 ──────────────────────────────────────────  (solid)
--
--  ACTIVE         ▓▓ 󰍉 lua█                          2/9  ▓▓
--                 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  (heavy)

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local git = require("custom.explorer.git")
local icons = require("custom.explorer.icons")

local api = vim.api
local M = {}

local function set_buf_modifiable(buf, value)
  api.nvim_set_option_value("modifiable", value, { buf = buf })
end

-- ── Search bar constants ───────────────────────────────────────────────────
--
-- Display layout:  ' 󰍉  '  = 1 sp + icon(2 cols) + 2 sp = 5 display cols
-- ICON_PREFIX      = 5 plain spaces written into the buffer (col 0-4)
--
local SEARCH_ICON = " 󰍉  " -- overlay (5 display cols)
local ICON_PREFIX = "     " -- 5 spaces in the buffer
local PLACEHOLDER = "filter files…"

-- Exported so search.lua can mirror this constant.
M.ICON_PREFIX = ICON_PREFIX

-- ── Sign column constant ───────────────────────────────────────────────────
--
-- Two spaces reserved at the start of every item row.
-- git.lua and marks.lua overlay this slot; SIGN_PH must stay in sync
-- with the SIGN_WIDTH constant in git.lua.
local SIGN_PH = "  " -- 2 display-column placeholder
local SIGN_PH_WIDTH = #SIGN_PH

-- ── paint_header ──────────────────────────────────────────────────────────

function M.paint_header()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.hdr_ns, 0, -1)

  local c = cfg.get()
  local is_active = S.search_active
  local has_filter = S.filter and S.filter ~= ""
  local line0 = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""

  local bg_hl = is_active and "ExplorerSearchBgActive" or "ExplorerSearchBg"
  local ico_hl = is_active and "ExplorerSearchIconActive" or "ExplorerSearchIcon"
  local sep_hl = is_active and "ExplorerSearchBorderActive" or "ExplorerSearchBorder"

  -- 1. Background wash
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    end_col = -1,
    hl_group = bg_hl,
    hl_eol = true,
    priority = 5,
  })

  -- 2. Icon overlay
  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_text = { { SEARCH_ICON, ico_hl } },
    virt_text_pos = "overlay",
    priority = 100,
  })

  -- 3a. Placeholder (idle, no filter)
  if line0 == ICON_PREFIX and not is_active then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  end

  -- 3b. Filter text highlight (filter set, not typing)
  if has_filter and not is_active and #line0 > #ICON_PREFIX then
    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, #ICON_PREFIX, {
      end_row = 0,
      end_col = #line0,
      hl_group = "ExplorerSearchActiveText",
      priority = 60,
    })
  end

  -- 4. Match-count / result-position badge
  if has_filter and c.search_count then
    local total = #S.items
    local label, badge_hl

    if is_active then
      badge_hl = "ExplorerSearchCountActive"
      if total == 0 then
        label = " no matches "
      else
        local cur = S._search_cursor or 0
        label = cur > 0 and (" " .. cur .. "/" .. total .. " ") or (" " .. total .. " ")
      end
    else
      badge_hl = "ExplorerSearchCount"
      label = total == 0 and " no matches " or (" " .. total .. (total == 1 and " match " or " matches "))
    end

    pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
      virt_text = { { label, badge_hl } },
      virt_text_pos = "right_align",
      priority = 70,
    })
  end

  -- 5. Separator virt_line below the search bar
  --    ╌╌╌ idle (no filter)
  --    ─── filter active but user not typing
  --    ━━━ user currently typing (insert mode) — heavy line for emphasis
  local win_w = c.width
  if S.win and api.nvim_win_is_valid(S.win) then
    win_w = api.nvim_win_get_width(S.win)
  end
  local sep_char, sep_hl
  if is_active then
    sep_char = "━"
    sep_hl = "ExplorerSearchBorderActive"
  elseif has_filter then
    sep_char = "─"
    sep_hl = "ExplorerSearchBorderFilter"
  else
    sep_char = "╌"
    sep_hl = "ExplorerSearchBorder"
  end
  local sep = sep_char:rep(win_w)

  pcall(api.nvim_buf_set_extmark, buf, S.hdr_ns, 0, 0, {
    virt_lines = { { { sep, sep_hl } } },
    priority = 100,
  })
end

-- ── _reveal_cursor ────────────────────────────────────────────────────────

function M._reveal_cursor(path)
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  for i, it in ipairs(S.items) do
    if it.path == path then
      local target_row = i + 1
      pcall(api.nvim_win_set_cursor, S.win, { target_row, 0 })
      pcall(api.nvim_win_call, S.win, function()
        vim.cmd("normal! zz")
      end)
      return
    end
  end
end

-- ── Debounced full render ─────────────────────────────────────────────────

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
        if S.search_active then
          require("custom.explorer.search").on_items_updated()
        else
          M._paint()
          git.apply()
        end
        local target = S._reveal_target
        if target then
          S._reveal_target = nil
          M._reveal_cursor(target)
        end
      end)
    )
  end)
end

-- ── _build_item_lines ─────────────────────────────────────────────────────
--
-- Builds the raw buffer lines and highlight specs for all S.items.
-- SIGN_PH is hoisted outside the loop — it is a constant string and
-- computing #SIGN_PH once here avoids redundant work per item.

local function build_item_lines()
  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  local lines = {}
  local hls = {}

  local sp_w = SIGN_PH_WIDTH -- 2, hoisted out of the per-item loop

  for _, item in ipairs(S.items) do
    -- Tree connector prefix
    local prefix = ""
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    -- File / directory icon
    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = item.is_open and "ExplorerIconDirOpen" or "ExplorerIconDir"
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. " "

    -- Column positions
    local name_col = sp_w + #prefix + #icon
    local line = SIGN_PH .. prefix .. icon .. item.name

    lines[#lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    -- 0-based row = index into S.items
    local row = #lines
    local c0 = sp_w
    local c1 = c0 + #prefix

    hls[#hls + 1] = { row, c0, c1, "ExplorerConnector" }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c1 + #icon, icon_hl }
    end
    hls[#hls + 1] = {
      row,
      name_col,
      name_col + #item.name,
      item.is_dir and "ExplorerDirectory" or "ExplorerFile",
    }
  end

  return lines, hls
end

-- ── _paint ────────────────────────────────────────────────────────────────

function M._paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  if S.search_active then
    return
  end -- don't overwrite while user is typing

  -- Snapshot cursor position by file path so we can restore it after rewrite
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
  local header_text = ICON_PREFIX .. (S.filter or "")
  local all_lines = { header_text }
  vim.list_extend(all_lines, item_lines)

  set_buf_modifiable(buf, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_set_extmark, buf, S.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
      priority = 10,
    })
  end
  set_buf_modifiable(buf, false)

  M.paint_header()

  -- Restore cursor to the same file, clamped to valid range
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

-- ── _paint_items_only ─────────────────────────────────────────────────────
--
-- Called while the user is typing in the search bar.  Line 1 (the search
-- bar) must NOT be rewritten — insert mode is still active on that line.

function M._paint_items_only()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local item_lines, hls = build_item_lines()

  set_buf_modifiable(buf, true)
  api.nvim_buf_set_lines(buf, 1, -1, false, item_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 1, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_set_extmark, buf, S.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
      priority = 10,
    })
  end

  -- Only re-lock if the user is no longer typing.
  -- deactivate() handles the lock when InsertLeave fires.
  if not S.search_active then
    set_buf_modifiable(buf, false)
  end

  git.apply()
end

return M
