-- custom/explorer/render.lua

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local git = require("custom.explorer.git")
local icons = require("custom.explorer.icons")
local search_ui = require("custom.explorer.search_ui")

local api = vim.api
local fn = vim.fn
local M = {}

local function set_modifiable(buf, v)
  api.nvim_set_option_value("modifiable", v, { buf = buf })
end

M.ICON_PREFIX = search_ui.INPUT_PREFIX

local SIGN_PH = "  "
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
      local target = search_ui.line_for_item(i) -- i
      pcall(api.nvim_win_set_cursor, S.win, { target, 0 })
      pcall(api.nvim_win_call, S.win, function()
        vim.cmd("normal! zz")
      end)
      return
    end
  end
end

-- ── Timer-based debounced render ──────────────────────────────────────────

local _render_timer = nil

function M.render()
  S.build_tok = S.build_tok + 1
  local tok = S.build_tok

  if _render_timer then
    _render_timer:stop()
    _render_timer = nil
  end

  _render_timer = vim.defer_fn(function()
    _render_timer = nil
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
      return
    end

    tok = S.build_tok
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
  end, 20)
end

-- ── _build_item_lines ─────────────────────────────────────────────────────

local function build_item_lines()
  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  local lines = {}
  local hls = {}
  local sp_w = SIGN_PH_WIDTH

  for _, item in ipairs(S.items) do
    local prefix = ""
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = item.is_open and "ExplorerIconDirOpen" or "ExplorerIconDir"
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. " "

    local name_col = sp_w + #prefix + #icon
    local line = SIGN_PH .. prefix .. icon .. item.name
    lines[#lines + 1] = line
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    local row = search_ui.row_for_item(#lines) -- zero‑based

    hls[#hls + 1] = { row, sp_w, sp_w + #prefix, "ExplorerConnector" }

    if icon_hl then
      hls[#hls + 1] = { row, sp_w + #prefix, sp_w + #prefix + #icon, icon_hl }
    end

    local name_hl = item.is_dir and (item.is_open and "ExplorerDirectoryOpen" or "ExplorerDirectory") or "ExplorerFile"
    hls[#hls + 1] = { row, name_col, name_col + #item.name, name_hl }
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
  end

  -- snapshot cursor
  local saved_view
  local cursor_path
  if S.win and api.nvim_win_is_valid(S.win) then
    api.nvim_win_call(S.win, function()
      saved_view = fn.winsaveview()
    end)
    local r = saved_view and saved_view.lnum or api.nvim_win_get_cursor(S.win)[1]
    local idx = search_ui.item_index_from_line(r)
    if idx then
      local it = S.items[idx]
      if it then
        cursor_path = it.path
      end
    end
  end

  -- build items (no spacer lines)
  local item_lines, hls = build_item_lines()
  local all_lines = item_lines -- formerly prepended by spacer_lines

  set_modifiable(buf, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(buf, S.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
      priority = 10,
    })
  end
  set_modifiable(buf, false)

  M.paint_header()

  -- restore cursor
  if S.win and api.nvim_win_is_valid(S.win) then
    local total = #all_lines
    if total == 0 then
      return
    end

    local target_line
    if cursor_path then
      for i, item in ipairs(S.items) do
        if item.path == cursor_path then
          target_line = search_ui.line_for_item(i) -- i
          break
        end
      end
    end

    local cur = (saved_view and saved_view.lnum) or api.nvim_win_get_cursor(S.win)[1]
    local row = target_line or math.max(1, math.min(cur, total))

    api.nvim_win_call(S.win, function()
      if saved_view then
        saved_view.lnum = row
        saved_view.col = 0
        -- no header, so no topline clamp needed (topline is always >= 1)
        fn.winrestview(saved_view)
      else
        pcall(api.nvim_win_set_cursor, S.win, { row, 0 })
      end
    end)

    search_ui.lock_tree_view()
  end
end

-- ── _paint_items_only ─────────────────────────────────────────────────────

function M._paint_items_only()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local item_lines, hls = build_item_lines()

  set_modifiable(buf, true)
  -- ensure buffer has at least one line (no header lines)
  if api.nvim_buf_line_count(buf) < 1 then
    api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, item_lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    api.nvim_buf_set_extmark(buf, S.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
      priority = 10,
    })
  end

  if not S.search_active then
    set_modifiable(buf, false)
  end
  git.apply()
end

return M
