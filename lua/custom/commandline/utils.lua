local M = {}

function M.clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

function M.ease_out_cubic(t)
  local t1 = t - 1
  return t1 * t1 * t1 + 1
end

function M.safe_win_close(win)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

function M.safe_buf_delete(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

return M
