--------------------------------------------------------------------------------
-- custom/terminal_manager/sidebar.lua
-- Render the sidebar; includes split indicators and venv badges.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local hl_mod = require("custom.terminal_manager.highlights")

local M = {}

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
  local meta = { term_rows = {}, new_row = nil, profiles_row = nil, help_row = nil }
  local hls = {}

  -- Title – show split mode indicator
  local title_suffix = state.split_mode and " [split]" or ""
  lines[1] = string.format("  ▌ TERMINALS (%d)%s", cnt, title_suffix)
  hls[#hls + 1] = { 0, 0, -1, "TermManagerHeader" }
  lines[2] = ""
  local row = 3

  -- Terminal list
  if cnt == 0 then
    lines[row] = "  (no terminals — press n)"
    hls[#hls + 1] = { row - 1, 0, -1, "TermManagerPlaceholder" }
    row = row + 1
  else
    for i, t in ipairs(state.terminals) do
      meta.term_rows[row] = i

      local alive = utils.term_alive(t.buf)
      local active1 = (t.id == state.active_id)
      local active2 = state.split_mode and (t.id == state.active_id2)
      local active = active1 or active2

      -- Arrow: ▶ for primary, ▷ for secondary split pane
      local arrow = "  "
      if active1 then
        arrow = "▶ "
      elseif active2 then
        arrow = "▷ "
      end

      local dot = alive and "●" or "○"
      local icon = (t.profile and t.profile.icon) or "$"

      -- Show venv badge if detected
      local venv_badge = ""
      if t.venv and t.venv.display then
        venv_badge = " " .. t.venv.display:sub(1, 2) -- just the emoji
      end

      local max_name = math.max(1, w - 9 - #venv_badge)
      local name = t.name
      if #name > max_name then
        name = name:sub(1, max_name - 1) .. "…"
      end

      lines[row] = string.format("  %s%s %s %s%s", arrow, dot, icon, name, venv_badge)

      local line_hl = active and "TermManagerActive" or alive and "TermManagerAlive" or "TermManagerDead"
      hls[#hls + 1] = { row - 1, 0, -1, line_hl }

      if active1 then
        hls[#hls + 1] = { row - 1, 2, 5, "TermManagerArrow" }
      elseif active2 then
        hls[#hls + 1] = { row - 1, 2, 5, "TermManagerWinbarHint" }
      end

      local dot_col = 4
      local dot_hl = alive and hl_mod.accent_hl((t.profile or {}).color) or "TermManagerDead"
      hls[#hls + 1] = { row - 1, dot_col, dot_col + 3, dot_hl }

      row = row + 1
    end
  end

  -- Profile keymaps section
  local km_list = require("custom.terminal_manager.profiles").keymap_list()
  if #km_list > 0 then
    lines[row] = ""
    row = row + 1
    lines[row] = "  " .. sep
    hls[#hls + 1] = { row - 1, 0, -1, "TermManagerSep" }
    row = row + 1
    lines[row] = "  ⌨ profile keys"
    hls[#hls + 1] = { row - 1, 0, -1, "TermManagerHelpHint" }
    row = row + 1
    for _, km in ipairs(km_list) do
      local icon = km.icon or "$"
      local km_str = km.keymap
      local avail = math.max(1, w - 4 - #km_str - #icon - 3)
      local name = km.name
      if #name > avail then
        name = name:sub(1, avail - 1) .. "…"
      end
      lines[row] = string.format("  %s  %s %s", km_str, icon, name)
      hls[#hls + 1] = { row - 1, 2, 2 + #km_str, "SpecialKey" }
      hls[#hls + 1] = { row - 1, 2 + #km_str + 2, 2 + #km_str + 2 + #icon, hl_mod.accent_hl(km.color) }
      row = row + 1
    end
  end

  -- Footer
  lines[row] = ""
  row = row + 1
  lines[row] = "  " .. sep
  hls[#hls + 1] = { row - 1, 0, -1, "TermManagerSep" }
  row = row + 1

  meta.new_row = row
  lines[row] = "  + new terminal"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerNew" }
  row = row + 1

  meta.profiles_row = row
  lines[row] = "  ≡ profiles"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerHelpHint" }
  row = row + 1

  meta.help_row = row
  lines[row] = "  ? help"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerHelpHint" }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(buf, state.ns, h[4], h[1], h[2], h[3])
  end

  state.sidebar_meta = meta

  if utils.win_ok(state.ui.sidebar_win) and state.active_id then
    for r, i in pairs(meta.term_rows) do
      if state.terminals[i] and state.terminals[i].id == state.active_id then
        pcall(vim.api.nvim_win_set_cursor, state.ui.sidebar_win, { r, 0 })
        break
      end
    end
  end
end

function M.cursor_term_idx()
  if not utils.win_ok(state.ui.sidebar_win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]
  return state.sidebar_meta.term_rows[row]
end

function M.select()
  local idx = M.cursor_term_idx()
  if idx then
    local t = state.terminals[idx]
    local sp = require("custom.terminal_manager.split")
    -- If split is active and user holds Shift (can't detect that), default pane 1.
    -- Sidebar always targets primary pane on <CR>; use 's' to place in pane 2.
    require("custom.terminal_manager.terminal").show(t)
    return
  end
  if not utils.win_ok(state.ui.sidebar_win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]
  local meta = state.sidebar_meta
  if row == meta.new_row then
    require("custom.terminal_manager").new_term()
  elseif row == meta.profiles_row then
    require("custom.terminal_manager.profile_manager").open()
  elseif row == meta.help_row then
    require("custom.terminal_manager.help").open()
  end
end

function M.select_pane2()
  -- Place selected terminal in pane 2 (split mode).
  local idx = M.cursor_term_idx()
  if not idx then
    return
  end
  local t = state.terminals[idx]
  require("custom.terminal_manager.split").show_in_pane(t, 2)
end

function M.delete()
  local idx = M.cursor_term_idx()
  if idx then
    require("custom.terminal_manager").delete_term(state.terminals[idx].id)
  end
end

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
        require("custom.terminal_manager.winbar").update_all()
      end
    end)
  end)
end

function M.restart()
  local idx = M.cursor_term_idx()
  if idx then
    require("custom.terminal_manager.terminal").restart(state.terminals[idx])
  end
end

function M.move(delta)
  if not utils.win_ok(state.ui.sidebar_win) then
    return
  end
  local rows = {}
  for r in pairs(state.sidebar_meta.term_rows) do
    rows[#rows + 1] = r
  end
  if #rows == 0 then
    return
  end
  table.sort(rows)
  local cur = vim.api.nvim_win_get_cursor(state.ui.sidebar_win)[1]
  local pos = 1
  for i, r in ipairs(rows) do
    if r >= cur then
      pos = i
      break
    end
    pos = i
  end
  local new_pos = math.max(1, math.min(#rows, pos + delta))
  vim.api.nvim_win_set_cursor(state.ui.sidebar_win, { rows[new_pos], 0 })
end

return M
