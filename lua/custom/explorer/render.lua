-- custom/explorer/render.lua
--
-- Buffer layout (1-based lines / 0-based rows):
--
--   Line 1  row 0  ╭──── SEARCH ────╮     ← search bar top border
--   Line 2  row 1  │  󰍉  filter…    │     ← search bar input row
--   Line 3  row 2  ╰────────────────╯     ← search bar bottom border
--   Line 4  row 3  │  ╰─ 󰢱 init.lua       ← S.items[1]
--   Line 5  row 4  │  ├─ 󰢱 foo.lua        ← S.items[2]
--   …
--
-- Coordinate rules (delegated to search_ui):
--   S.items[i]  →  line search_ui.line_for_item(i),  row search_ui.row_for_item(i)
--
-- Sign column (cols 0-1 of every item row):
--   Always written as two spaces ("  ") in the buffer text.
--   Overlaid by git.lua (priority 20) or marks.lua (priority 30).
--   The 2-col width is a constant shared with git.lua via SIGN_PH_WIDTH.
--
-- Changes vs original:
--
--  1. build_item_lines() now reads item._prefix (pre-computed by tree.lua)
--     instead of reassembling the connector string from item.parents_last on
--     every render.  This removes the per-item unpack + loop.
--
--  2. marks.apply() is now called from _paint() — it was previously only
--     called from marks.lua itself on toggle, leaving marks stale after a
--     full repaint triggered by a file-watcher event.
--
--  3. diagnostics.apply() is called at the end of _paint() and
--     _paint_items_only() when the diagnostics module is available.

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local git = require("custom.explorer.git")
local marks = require("custom.explorer.marks")
local icons = require("custom.explorer.icons")
local search_ui = require("custom.explorer.search_ui")

local api = vim.api
local M = {}

-- ── Namespaces ────────────────────────────────────────────────────────────
-- Separate from S.ns so they can be cleared independently.
local ACTIVE_NS = api.nvim_create_namespace("explorer_active")
local HIDDEN_NS = api.nvim_create_namespace("explorer_hidden")

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

-- ── Diagnostics helper ────────────────────────────────────────────────────
--
-- Lazily loaded so the diagnostics module is optional.  If it doesn't exist,
-- the calls below silently no-op.

local function apply_diagnostics()
  local ok, diag = pcall(require, "custom.explorer.diagnostics")
  if ok and type(diag.apply) == "function" then
    diag.apply()
  end
end

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

-- ── Forward declarations ──────────────────────────────────────────────────
-- apply_active_indicator and apply_hidden_badge are defined later in the file
-- but referenced by M.render() and M._paint() closures.  Forward-declare so
-- Lua can close over the upvalue correctly.

local apply_active_indicator
local apply_hidden_badge

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
          marks.apply()
          apply_active_indicator()
          apply_hidden_badge()
          apply_diagnostics()
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
-- Reads item._prefix (pre-computed by tree.lua during the walk) instead of
-- reconstructing it from item.parents_last.  Eliminates the per-item unpack
-- loop and the per-item prefix table allocation in the render hot path.
--
-- Falls back to the legacy parents_last reconstruction if _prefix is absent
-- (e.g. for items produced by older code during a live upgrade).

local function build_item_lines()
  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  local lines = {}
  local hls = {}

  local sp_w = SIGN_PH_WIDTH -- 2, hoisted out of the loop

  for _, item in ipairs(S.items) do
    -- ── Tree connector prefix ─────────────────────────────────────────────
    local prefix = item._prefix or ""

    -- ── File / directory icon ─────────────────────────────────────────────
    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = item.is_open and "ExplorerIconDirOpen" or "ExplorerIconDir"
    else
      icon_raw, icon_hl = ifn(item.path, false, item.is_link)
    end
    local icon = icon_raw .. " "

    -- ── Column positions ──────────────────────────────────────────────────
    local name_col = sp_w + #prefix + #icon
    local line = SIGN_PH .. prefix .. icon .. item.name

    lines[#lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

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

-- ── apply_active_indicator ────────────────────────────────────────────────
--
-- Highlights the row whose path matches S.active_buf_path with
-- ExplorerActiveFile on the name column and a right-aligned glyph.
-- Called from _paint() and _paint_items_only() after item lines are written.

local ACTIVE_GLYPH = " " -- nf-fa-circle / nf-cod-circle-filled

apply_active_indicator = function()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, ACTIVE_NS, 0, -1)
  local active = S.active_buf_path
  if not active then
    return
  end
  for i, item in ipairs(S.items) do
    if item.path == active then
      local row = search_ui.row_for_item(i)
      local col_name = item._col_name or 0
      local col_end = item._col_name_end or (col_name + #item.name)
      -- Brighten the filename
      pcall(require("custom.ui.render").set_extmark, buf, ACTIVE_NS, row, col_name, {
        end_col = col_end,
        hl_group = "ExplorerActiveFile",
        priority = 12, -- above base (10), below git (20) / marks (30)
      })
      -- Right-aligned dot marker
      pcall(require("custom.ui.render").set_extmark, buf, ACTIVE_NS, row, 0, {
        virt_text = { { ACTIVE_GLYPH, "ExplorerActiveMark" } },
        virt_text_pos = "right_align",
        priority = 12,
      })
      break
    end
  end
end
-- Export so init.lua can call a lightweight repaint without a full rebuild.
M.apply_active_indicator = apply_active_indicator

-- ── apply_hidden_badge ────────────────────────────────────────────────────
--
-- Writes the hidden-file count as a real buffer line at the end of the item
-- list.  Real content is guaranteed to render — virt_lines on a non-modifiable
-- nofile buffer can silently fail depending on Neovim internals.
--
-- The cursor is never placed on this line because lock_tree_view() clamps
-- navigation to [HEADER_LINES+1 … HEADER_LINES+#S.items].

local HIDDEN_ICON = "󰘓 " -- nf-md-eye_off

apply_hidden_badge = function()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, HIDDEN_NS, 0, -1)

  local c = cfg.get()
  if c.show_hidden then
    return
  end
  local n = S.hidden_count or 0
  if n == 0 then
    return
  end

  local label = "  " .. HIDDEN_ICON .. n .. (n == 1 and " hidden file" or " hidden files")

  -- Append as a real line so it is always visible.
  set_buf_modifiable(buf, true)
  local line_count = api.nvim_buf_line_count(buf)
  api.nvim_buf_set_lines(buf, line_count, line_count, false, { label })
  -- Highlight the entire line with ExplorerHiddenCount
  api.nvim_buf_set_extmark(buf, HIDDEN_NS, line_count, 0, {
    end_col = #label,
    hl_group = "ExplorerHiddenCount",
    priority = 8,
  })
  set_buf_modifiable(buf, false)
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

  -- ── Overlay layers (written after buffer text is locked) ──────────────
  apply_active_indicator()

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
  if not S.search_active then
    set_buf_modifiable(buf, false)
  end

  git.apply()
  marks.apply()
  apply_active_indicator()
  apply_hidden_badge()
  apply_diagnostics()
end

return M
