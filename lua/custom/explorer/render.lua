-- explorer/render.lua
--
-- Buffer layout (1-based line numbers, 0-based rows):
--
--   Line 1  row 0 : blank — the search float covers this row completely.
--   Line 2  row 1 : separator — a dim ─── line that visually frames the bar.
--   Line 3+ row 2+: tree items.  S.items[i] → line i+2, row i+1.
--
-- Coordinate mapping:
--   1-based cursor row r  →  S.items[r-2]   (valid when r ≥ 3)
--   S.items index i       →  1-based line i+2,  0-based row i+1
--
-- Git extmarks live in git_ns; they use the same 0-based row i+1.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local tree = require 'custom.explorer.tree'
local git = require 'custom.explorer.git'
local icons = require 'custom.explorer.icons'

local api = vim.api
local M = {}

local SEP_NS = api.nvim_create_namespace 'explorer_sep'

-------------------------------------------------------------------------------
-- Separator line (buffer line 2, row 1)
-- Rendered as virtual text over the blank line so it always fills the width.
-------------------------------------------------------------------------------
local function paint_separator(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, SEP_NS, 0, -1)

  local width = (S.win and api.nvim_win_is_valid(S.win)) and api.nvim_win_get_width(S.win) or 80
  local sep = string.rep('─', width)

  pcall(api.nvim_buf_set_extmark, buf, SEP_NS, 1, 0, {
    virt_text = { { sep, 'ExplorerSeparator' } },
    virt_text_pos = 'overlay',
    priority = 5,
  })
end

-------------------------------------------------------------------------------
-- Debounced full render (schedules an async tree build)
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
        S.items = items
        M._paint()
        git.apply()
      end)
    )
  end)
end

-------------------------------------------------------------------------------
-- _paint: synchronous buffer write + cursor restore
-------------------------------------------------------------------------------
function M._paint()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local c = cfg.get()
  local tc = c.tree
  local ifn = S.icon_fn or icons.resolve()

  -- ── 1. Snapshot cursor position by file path (not row number) ────────────
  local cursor_path
  if S.win and api.nvim_win_is_valid(S.win) then
    local row = api.nvim_win_get_cursor(S.win)[1] -- 1-based
    if row >= 3 then
      local it = S.items[row - 2]
      if it then
        cursor_path = it.path
      end
    end
  end

  -- ── 2. Build line list ───────────────────────────────────────────────────
  -- Line 1 = blank (search float anchor)
  -- Line 2 = blank (separator painted via virt_text by paint_separator)
  local lines = { '', '' }
  local hls = {} -- { 0-based-row, col_start, col_end, hl_group }

  for _, item in ipairs(S.items) do
    -- Tree connector
    local prefix = ''
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    -- Icon
    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and icons.DIR_OPEN or icons.DIR_CLOSED
      icon_hl = 'Directory'
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. ' '

    -- Sign placeholder: 2 spaces that git extmarks overwrite via overlay
    local sign_ph = '  '
    local name_col = #sign_ph + #prefix + #icon
    local line = sign_ph .. prefix .. icon .. item.name

    lines[#lines + 1] = line

    -- Column metadata used by git.apply()
    item._col_name = name_col
    item._col_name_end = name_col + #item.name

    -- 0-based row:
    --   lines[1] = "" → row 0 (search anchor)
    --   lines[2] = "" → row 1 (separator)
    --   lines[3] = items[1] → row 2
    --   lines[i+2] = items[i] → row i+1
    local row = #lines - 1 -- correct: after push, item[1] → row 2 ✓
    local c0 = #sign_ph -- connector start
    local c1 = c0 + #prefix -- icon start

    hls[#hls + 1] = { row, c0, c1, 'NonText' }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c1 + #icon, icon_hl }
    end
    hls[#hls + 1] = { row, name_col, name_col + #item.name, item.is_dir and 'Directory' or 'Normal' }
  end

  -- ── 3. Write buffer ───────────────────────────────────────────────────────
  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_add_highlight, buf, S.ns, h[4], h[1], h[2], h[3])
  end
  api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Repaint the separator virt_text (cleared by set_lines)
  paint_separator(buf)

  -- ── 4. Restore cursor by path ─────────────────────────────────────────────
  if S.win and api.nvim_win_is_valid(S.win) then
    local target
    if cursor_path then
      for i, item in ipairs(S.items) do
        if item.path == cursor_path then
          target = i + 2 -- 1-based: line1=anchor, line2=sep, line3=item[1]
          break
        end
      end
    end
    local max = math.max(3, #lines)
    local cur = api.nvim_win_get_cursor(S.win)[1]
    local row = target and math.min(target, max) or math.max(3, math.min(cur, max))
    pcall(api.nvim_win_set_cursor, S.win, { row, 0 })
  end
end

return M
