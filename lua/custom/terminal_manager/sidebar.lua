--------------------------------------------------------------------------------
-- custom.terminal_manager/sidebar.lua
-- Renders the sidebar buffer and handles all sidebar keyboard actions.
--
-- All calls back into the public API (new_term, delete_term, close, …) use
-- lazy `require("custom.terminal_manager")` inside function bodies so this module
-- can be required before custom.terminal_manager/init.lua finishes loading.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local hl_mod = require("custom.terminal_manager.highlights")

local M = {}

-- ── Rendering ─────────────────────────────────────────────────────────────────

--- Rebuild sidebar buffer content and highlights.
--- Populates state.sidebar_meta for action handlers to consume.
function M.render()
  local buf = state.ui.sidebar_buf
  if not utils.buf_ok(buf) then
    return
  end

  local cfg = require("custom.terminal_manager").config
  local w = cfg.sidebar_width
  local sep = ("─"):rep(w - 2)
  local cnt = #state.terminals

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  local lines = {}
  -- meta.term_rows: { [1-based row] = index into state.terminals }
  local meta = { term_rows = {}, new_row = nil, help_row = nil }
  -- hls: { { row0, col_s, col_e, hl_group }, … }
  -- Less-specific (wider) highlights are added first; narrower ones after,
  -- so Neovim's priority ordering resolves in our favour.
  local hls = {}

  -- ── Row 1: coloured title ─────────────────────────────────────────────────
  lines[1] = string.format("  ▌ TERMINALS (%d)", cnt)
  hls[#hls + 1] = { 0, 0, -1, "TermManagerHeader" }

  -- ── Row 2: blank spacer ──────────────────────────────────────────────────
  lines[2] = ""

  local row = 3 -- 1-based row index for the next rendered line

  -- ── Terminal list ─────────────────────────────────────────────────────────
  if cnt == 0 then
    lines[row] = "  (no terminals — press n)"
    hls[#hls + 1] = { row - 1, 0, -1, "TermManagerPlaceholder" }
    row = row + 1
  else
    for i, t in ipairs(state.terminals) do
      meta.term_rows[row] = i

      local alive = utils.term_alive(t.buf)
      local active = (t.id == state.active_id)
      local arrow = active and "▶" or " "
      local dot = alive and "●" or "○"
      local icon = (t.profile and t.profile.icon) or "$"

      -- Truncate name so the line fits inside the sidebar window.
      -- Fixed prefix: indent(2)+arrow(1)+sp(1)+dot(1)+sp(1)+icon(1)+sp(1) = 8 chars.
      local max_name = math.max(1, w - 8)
      local name = t.name
      if #name > max_name then
        name = name:sub(1, max_name - 1) .. "…"
      end

      lines[row] = string.format("  %s %s %s %s", arrow, dot, icon, name)

      -- ① Full-line state highlight
      local line_hl = active and "TermManagerActive" or alive and "TermManagerAlive" or "TermManagerDead"
      hls[#hls + 1] = { row - 1, 0, -1, line_hl }

      -- ② Arrow glyph (▶ = 3 UTF-8 bytes, starting at byte offset 2)
      if active then
        hls[#hls + 1] = { row - 1, 2, 5, "TermManagerArrow" }
      end

      -- ③ Dot glyph (●/○ = 3 bytes each)
      -- Byte layout: active   "  ▶ ●…" → indent(2)+▶(3)+sp(1) = dot at 6
      --              inactive "    ●…" → indent(2)+sp+sp        = dot at 4
      local dot_col = active and 6 or 4
      local dot_hl = alive and hl_mod.accent_hl((t.profile or {}).color) or "TermManagerDead"
      hls[#hls + 1] = { row - 1, dot_col, dot_col + 3, dot_hl }

      row = row + 1
    end
  end

  -- ── Footer ───────────────────────────────────────────────────────────────
  lines[row] = ""
  row = row + 1

  lines[row] = "  " .. sep
  hls[#hls + 1] = { row - 1, 0, -1, "TermManagerSep" }
  row = row + 1

  meta.new_row = row
  lines[row] = "  + new terminal"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerNew" }
  row = row + 1

  meta.help_row = row
  lines[row] = "  ? help"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerHelpHint" }

  -- ── Commit to the buffer ──────────────────────────────────────────────────
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(buf, state.ns, h[4], h[1], h[2], h[3])
  end

  state.sidebar_meta = meta

  -- Move sidebar cursor to the active terminal's row.
  if utils.win_ok(state.ui.sidebar_win) and state.active_id then
    for r, i in pairs(meta.term_rows) do
      if state.terminals[i] and state.terminals[i].id == state.active_id then
        pcall(vim.api.nvim_win_set_cursor, state.ui.sidebar_win, { r, 0 })
        break
      end
    end
  end
end

-- ── Action helpers ────────────────────────────────────────────────────────────

--- Return the terminals[] index under the sidebar cursor, or nil.
function M.cursor_term_idx()
  if not utils.win_ok(state.ui.sidebar_win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]
  return state.sidebar_meta.term_rows[row]
end

--- <CR> / double-click: select the terminal under the cursor.
--- Also handles clicks on the "+ new terminal" and "? help" footer rows.
function M.select()
  local idx = M.cursor_term_idx()
  if idx then
    require("custom.terminal_manager.terminal").show(state.terminals[idx])
    return
  end
  if not utils.win_ok(state.ui.sidebar_win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]
  if row == state.sidebar_meta.new_row then
    require("custom.terminal_manager").new_term()
  elseif row == state.sidebar_meta.help_row then
    require("custom.terminal_manager.help").open()
  end
end

--- d: delete the terminal under the cursor.
function M.delete()
  local idx = M.cursor_term_idx()
  if idx then
    require("custom.terminal_manager").delete_term(state.terminals[idx].id)
  end
end

--- r: prompt to rename the terminal under the cursor.
function M.rename()
  local idx = M.cursor_term_idx()
  if not idx then
    return
  end
  local t = state.terminals[idx]
  vim.ui.input({ prompt = "Rename: ", default = t.name }, function(name)
    vim.schedule(function()
      if name and name ~= "" then
        t.name = name
        M.render()
        require("custom.terminal_manager.winbar").update()
      end
    end)
  end)
end

--- R: force-restart the terminal under the cursor.
function M.restart()
  local idx = M.cursor_term_idx()
  if idx then
    require("custom.terminal_manager.terminal").restart(state.terminals[idx])
  end
end

--- j / k: move the sidebar cursor up/down, constrained to terminal rows only.
--- BUG-FIX vs original: when the cursor is below all terminal rows (e.g.
--- sitting on the footer), delta = -1 now correctly lands on the last terminal
--- instead of snapping back to the first one.
function M.move(delta)
  if not utils.win_ok(state.ui.sidebar_win) then
    return
  end

  -- Collect and sort the rows that actually contain terminals.
  local rows = {}
  for r in pairs(state.sidebar_meta.term_rows) do
    rows[#rows + 1] = r
  end
  if #rows == 0 then
    return
  end
  table.sort(rows)

  local cur = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]

  -- Find the nearest terminal row at-or-above `cur`.
  -- We update `pos` on every iteration so that, if `cur` is below all
  -- terminal rows, `pos` ends up pointing at the last terminal.
  local pos = 1
  for i, r in ipairs(rows) do
    if r >= cur then
      pos = i
      break
    end
    pos = i -- keep advancing; lands at #rows when cur > all rows
  end

  local new_pos = math.max(1, math.min(#rows, pos + delta))
  vim.api.nvim_win_set_cursor(state.ui.sidebar_win, { rows[new_pos], 0 })
end

return M
