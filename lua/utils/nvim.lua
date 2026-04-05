local M = {}

function M.augroup(name, opts)
  opts = opts or {}
  local clear = opts.clear
  if clear == nil then
    clear = true
  end
  return vim.api.nvim_create_augroup(name, { clear = clear })
end

function M.autocmd(events, opts)
  local spec = vim.tbl_extend("force", {}, opts or {})
  if type(spec.group) == "string" then
    spec.group = M.augroup(spec.group)
  end
  return vim.api.nvim_create_autocmd(events, spec)
end

function M.command(name, rhs, opts)
  return vim.api.nvim_create_user_command(name, rhs, opts or {})
end

function M.map(mode, lhs, rhs, opts)
  if lhs == false or lhs == nil or lhs == "" then
    return
  end
  return vim.keymap.set(mode, lhs, rhs, opts or {})
end

function M.buf_map(buf, mode, lhs, rhs, opts)
  local merged = vim.tbl_extend("force", { buffer = buf }, opts or {})
  return M.map(mode, lhs, rhs, merged)
end

function M.close_win(win, force)
  if win and vim.api.nvim_win_is_valid(win) then
    return pcall(vim.api.nvim_win_close, win, force ~= false)
  end
  return false
end

function M.bind_close_keys(buf, win, keys, opts)
  local close = function()
    M.close_win(win, true)
  end

  for _, key in ipairs(keys or { "q", "<Esc>" }) do
    M.buf_map(buf, "n", key, close, vim.tbl_extend("force", {
      silent = true,
      nowait = true,
    }, opts or {}))
  end

  M.autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close,
  })

  return close
end

return M
