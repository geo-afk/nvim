-- explorer/marks.lua
-- Multi-select via Space. Marked files show "● " in the sign column
-- (overlaid on top of the "  " placeholder, overriding git signs).
-- Batch operations (delete, copy, rename) operate on all marks when active.

local S = require 'custom.explorer.state'
local api = vim.api

local M = {}

local MARK_SIGN = '● '
local MARK_HL = 'ExplorerMark'

function M.setup_hl()
  local ok, sel = pcall(api.nvim_get_hl, 0, { name = 'Visual' })
  local fg = (ok and sel) and sel.fg or 0x7aa2f7
  pcall(api.nvim_set_hl, 0, MARK_HL, { fg = fg, bold = true })
end

-- Toggle mark on current item
function M.toggle(item)
  if not item or item.is_dir then
    return
  end -- only mark files for now
  if S.marks[item.path] then
    S.marks[item.path] = nil
  else
    S.marks[item.path] = true
  end
  M.apply()
end

-- Clear all marks
function M.clear()
  S.marks = {}
  M.apply()
end

-- Returns a list of marked paths, or {item.path} if no marks
function M.selection(fallback_item)
  local paths = vim.tbl_keys(S.marks)
  if #paths > 0 then
    return paths
  end
  if fallback_item and not fallback_item.is_dir then
    return { fallback_item.path }
  end
  return {}
end

-- Repaint mark signs (overlay extmarks on the sign placeholder column)
function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.mark_ns, 0, -1)

  for i, item in ipairs(S.items) do
    if S.marks[item.path] then
      pcall(api.nvim_buf_set_extmark, buf, S.mark_ns, i - 1, 0, {
        end_col = 2,
        virt_text = { { MARK_SIGN, MARK_HL } },
        virt_text_pos = 'overlay',
        priority = 30, -- higher than git (20) so marks win
      })
    end
  end
end

-- Count of active marks
function M.count()
  local n = 0
  for _ in pairs(S.marks) do
    n = n + 1
  end
  return n
end

return M
