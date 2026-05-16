local buffer = require("custom.ui.buffer")
local nvim_utils = require("utils.nvim")

local M = {}

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

function M.editor_size()
  local ui = vim.api.nvim_list_uis()[1]
  if ui then
    return ui.width, ui.height
  end
  return vim.o.columns, vim.o.lines
end

function M.center(width, height, opts)
  opts = opts or {}
  local editor_w, editor_h = M.editor_size()
  local row = math.floor((editor_h - height) / 2) + (opts.row_offset or 0)
  local col = math.floor((editor_w - width) / 2) + (opts.col_offset or 0)
  return clamp(row, 0, math.max(0, editor_h - height)), clamp(col, 0, math.max(0, editor_w - width))
end

function M.open_raw(buf, enter, config)
  return vim.api.nvim_open_win(buf, enter, config)
end

function M.open(buf, opts)
  opts = opts or {}
  local width = opts.width or 60
  local height = opts.height or 1
  local row = opts.row
  local col = opts.col

  if opts.position == nil or opts.position == "center" then
    row, col = M.center(width, height, opts)
  end

  local config = vim.tbl_extend("force", {
    relative = opts.relative or "editor",
    row = row or 0,
    col = col or 0,
    width = width,
    height = height,
    style = opts.style or "minimal",
    border = opts.border,
    focusable = opts.focusable ~= false,
    zindex = opts.zindex,
    noautocmd = opts.noautocmd,
  }, opts.config or {})

  for _, key in ipairs({ "title", "title_pos", "footer", "footer_pos" }) do
    if opts[key] ~= nil then
      config[key] = opts[key]
    end
  end

  local win = vim.api.nvim_open_win(buf, opts.enter ~= false, config)
  M.apply_options(win, opts.options)
  return win
end

function M.split(buf, opts)
  opts = opts or {}
  local side = opts.side == "right" and "botright" or "topleft"
  local size = tonumber(opts.size or opts.width)
  local cmd = side .. (size and (" " .. size) or "") .. (opts.vertical == false and "split" or "vsplit")
  vim.cmd(cmd)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  M.apply_options(win, opts.options)
  return win
end

function M.apply_options(win, options)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  for name, value in pairs(options or {}) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = win })
  end
end

function M.configure_float(win, opts)
  opts = opts or {}
  M.apply_options(
    win,
    vim.tbl_extend("force", {
      number = false,
      relativenumber = false,
      signcolumn = opts.signcolumn or "no",
      wrap = opts.wrap or false,
      cursorline = opts.cursorline or false,
      scrolloff = 0,
      foldcolumn = "0",
      statuscolumn = "",
    }, opts.options or {})
  )
  if opts.winhighlight or opts.winhl then
    M.apply_options(win, { winhighlight = opts.winhighlight or opts.winhl })
  end
  if opts.winblend ~= nil then
    M.apply_options(win, { winblend = opts.winblend })
  end
end

function M.close(win, force)
  return nvim_utils.close_win(win, force)
end

function M.close_pair(win, buf, opts)
  M.close(win, opts and opts.force ~= false)
  if buf and buffer.is_valid(buf) and (not opts or opts.delete_buf ~= false) then
    buffer.delete(buf, { force = true })
  end
end

function M.bind_close_keys(buf, win, keys, opts)
  return nvim_utils.bind_close_keys(buf, win, keys, opts)
end

return M
