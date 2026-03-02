-- custom/explorer/marks.lua
-- S.items[i] → 0-based row = i  (header row 0, item 1 at row 1)

local S = require 'custom.explorer.state'
local api = vim.api

local M = {}

local MARK_SIGN = '● '
local MARK_HL = 'ExplorerMark'

function M.setup_hl()
  local ok, sel = pcall(api.nvim_get_hl, 0, { name = 'Visual' })
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

function M.selection(fallback)
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
      -- row = i  (item 1 is at row 1, header is row 0)
      pcall(api.nvim_buf_set_extmark, buf, S.mark_ns, i, 0, {
        end_col = 2,
        virt_text = { { MARK_SIGN, MARK_HL } },
        virt_text_pos = 'overlay',
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
