-- custom/explorer/marks.lua
-- S.items[i] → 0-based row = i  (header row 0, item 1 at row 1)

local S = require("custom.explorer.state")
local search_ui = require("custom.explorer.search_ui")
local api = vim.api

local M = {}

local MARK_SIGN = "● "
local MARK_HL = "ExplorerMark"

function M.setup_hl()
  local ok, sel = pcall(api.nvim_get_hl, 0, { name = "Visual" })
  local fg = (ok and sel) and sel.fg or 0xffb3c6
  pcall(api.nvim_set_hl, 0, MARK_HL, { fg = fg, bold = true })
end

function M.toggle(item)
  if not item or item.is_dir then
    return
  end
  S.marks[item.path] = S.marks[item.path] and nil or true
  M.apply()
end

function M.clear()
  S.marks = {}
  M.apply()
end

function M.prune()
  local changed = false
  for path in pairs(S.marks) do
    if not vim.uv.fs_stat(path) then
      S.marks[path] = nil
      changed = true
    end
  end
  if changed then
    M.apply()
  end
end

function M.replace(old_path, new_path)
  if not old_path or not new_path or old_path == new_path then
    return
  end
  if S.marks[old_path] then
    S.marks[old_path] = nil
    S.marks[new_path] = true
    M.apply()
  end
end

function M.selection(fallback)
  M.prune()
  local paths = vim.tbl_keys(S.marks)
  if #paths > 0 then
    return paths
  end
  if fallback and not fallback.is_dir then
    return { fallback.path }
  end
  return {}
end

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.mark_ns, 0, -1)
  for i, item in ipairs(S.items) do
    if S.marks[item.path] then
      pcall(require("custom.ui.render").set_extmark, buf, S.mark_ns, search_ui.row_for_item(i), 0, {
        end_col = 2,
        virt_text = { { MARK_SIGN, MARK_HL } },
        virt_text_pos = "overlay",
        priority = 30,
      })
    end
  end
end

function M.count()
  local n = 0
  for _ in pairs(S.marks) do
    n = n + 1
  end
  return n
end

return M
