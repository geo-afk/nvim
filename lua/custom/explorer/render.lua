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
local search_ui = require("custom.explorer.search_ui")

local api = vim.api
local M = {}

local function set_buf_modifiable(buf, value)
  api.nvim_set_option_value("modifiable", value, { buf = buf })
end

M.ICON_PREFIX = search_ui.INPUT_PREFIX

-- ── Sign column constant ───────────────────────────────────────────────────
--
-- Two spaces reserved at the start of every item row.
-- git.lua and marks.lua overlay this slot; SIGN_PH must stay in sync
-- with the SIGN_WIDTH constant in git.lua.
local SIGN_PH = "  " -- 2 display-column placeholder
local SIGN_PH_WIDTH = #SIGN_PH

-- ── paint_header ──────────────────────────────────────────────────────────

function M.paint_header()
  search_ui.paint()
end

-- ── _reveal_cursor ────────────────────────────────────────────────────────

function M._reveal_cursor(path)
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  for i, it in ipairs(S.items) do
    if it.path == path then
      local target_row = search_ui.line_for_item(i)
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
    local prefix_tbl = {}
    for _, last in ipairs(item.parents_last) do
      prefix_tbl[#prefix_tbl + 1] = last and tc.blank or tc.vert
    end
    prefix_tbl[#prefix_tbl + 1] = item.is_last and tc.last or tc.branch
    local prefix = table.concat(prefix_tbl)

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
    local row = search_ui.row_for_item(#lines)
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
    local idx = search_ui.item_index_from_line(r)
    if idx then
      local it = S.items[idx]
      if it then
        cursor_path = it.path
      end
    end
  end

  local item_lines, hls = build_item_lines()
  local all_lines = search_ui.spacer_lines()
  vim.list_extend(all_lines, item_lines)

  set_buf_modifiable(buf, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(require("custom.ui.render").set_extmark, buf, S.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
      priority = 10,
    })
  end
  set_buf_modifiable(buf, false)

  M.paint_header()
  search_ui.lock_tree_view()

  -- Restore cursor to the same file, clamped to valid range
  if S.win and api.nvim_win_is_valid(S.win) then
    local target
    if cursor_path then
      for i, item in ipairs(S.items) do
        if item.path == cursor_path then
          target = search_ui.line_for_item(i)
          break
        end
      end
    end
    local total = #all_lines
    if total <= search_ui.HEADER_LINES then
      return
    end
    local cur = api.nvim_win_get_cursor(S.win)[1]
    local row = target and math.min(target, total) or math.max(search_ui.HEADER_LINES + 1, math.min(cur, total))
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
  if api.nvim_buf_line_count(buf) < search_ui.HEADER_LINES then
    api.nvim_buf_set_lines(buf, 0, -1, false, search_ui.spacer_lines())
  end
  api.nvim_buf_set_lines(buf, search_ui.HEADER_LINES, -1, false, item_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, search_ui.HEADER_LINES, -1)
  for _, h in ipairs(hls) do
    pcall(require("custom.ui.render").set_extmark, buf, S.ns, h[1], h[2], {
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
