local M = {}
local api = vim.api
local diag = vim.diagnostic

-- State for float window
M.state = {
  win = nil,
  buf = nil,
}

-- format diagnostics for display
local function format_diagnostics()
  local output = {}
  -- get all diagnostics in workspace
  local all_diag = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local diags = diag.get(buf)
    for _, d in ipairs(diags) do
      d.bufnr = buf
      table.insert(all_diag, d)
    end
  end

  table.sort(all_diag, function(a, b)
    return a.severity < b.severity
  end)

  for _, d in ipairs(all_diag) do
    local filename = vim.fn.bufname(d.bufnr)
    local severity = diag.severity[d.severity]
    local line = d.range.start.line + 1
    local text = d.message:gsub('\n', ' ')
    table.insert(output, string.format('%s:%d [%s] %s', filename, line, severity, text))
  end

  return output
end

-- show float
function M.open()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    return
  end

  local lines = format_diagnostics()
  if #lines == 0 then
    vim.notify('No diagnostics', vim.log.levels.INFO)
    return
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(math.min(#lines, vim.o.lines * 0.5))

  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = 2,
    col = 2,
    style = 'minimal',
    border = 'rounded',
  })

  M.state.win = win
  M.state.buf = buf
end

-- close float
function M.close()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_close(M.state.win, true)
    M.state.win = nil
    M.state.buf = nil
  end
end

-- toggle view
function M.toggle()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    M.close()
  else
    M.open()
  end
end

return M
