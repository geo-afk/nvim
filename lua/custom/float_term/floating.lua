--- custom/float_term/floating.lua
--- Floating Window Factory

local M = {}

local floats = {}
local id_seq = 0

local function new_id()
  id_seq = id_seq + 1
  return id_seq
end

-- ─── Geometry ────────────────────────────────────────────────────────────────

local function editor_size()
  return vim.o.columns, vim.o.lines - vim.o.cmdheight - 1
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function resolve_size(spec, total)
  if spec > 0 and spec < 1 then
    return math.floor(total * spec)
  end
  return math.floor(spec)
end

local function center_pos(cols, rows, width, height)
  return {
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
  }
end

-- ─── Win config ──────────────────────────────────────────────────────────────

local DEFAULTS = {
  position = "center",
  width = 0.70,
  height = 0.60,
  border = nil,
  title = nil,
  title_pos = "center",
  focusable = true,
  enter = true,
  modifiable = false,
  style = "minimal",
  zindex = 50,
}

local function build_win_config(opts, width, height)
  local cols, rows = editor_size()
  local pos = opts.position or "center"
  local row, col

  if pos == "center" then
    local p = center_pos(cols, rows, width, height)
    row, col = p.row, p.col
  elseif pos == "top" then
    row = 2
    col = math.floor((cols - width) / 2)
  elseif pos == "bottom" then
    row = rows - height - 2
    col = math.floor((cols - width) / 2)
  elseif pos == "cursor" then
    local cpos = vim.api.nvim_win_get_cursor(0)
    local winpos = vim.api.nvim_win_get_position(0)
    row = winpos[1] + cpos[1] - vim.fn.line("w0")
    col = winpos[2] + cpos[2]
    if row + height > rows then
      row = row - height - 1
    end
    if col + width > cols then
      col = cols - width - 1
    end
  elseif type(pos) == "table" then
    row = pos.row or 0
    col = pos.col or 0
  else
    local p = center_pos(cols, rows, width, height)
    row, col = p.row, p.col
  end

  row = clamp(row, 0, math.max(0, rows - height))
  col = clamp(col, 0, math.max(0, cols - width))

  local wc = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = opts.border,
    style = opts.style or "minimal",
    focusable = opts.focusable ~= false,
    zindex = opts.zindex or 50,
  }

  if opts.title then
    wc.title = " " .. opts.title .. " "
    wc.title_pos = opts.title_pos or "center"
  end
  if opts.footer then
    wc.footer = " " .. opts.footer .. " "
    wc.footer_pos = opts.footer_pos or "center"
  end

  return wc
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Open a floating window.
--- @param opts table
--- @return integer id, integer buf, integer win
function M.open(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, DEFAULTS)

  local cols, rows = editor_size()
  local width = clamp(resolve_size(opts.width, cols), 10, cols - 4)
  local height = clamp(resolve_size(opts.height, rows), 3, rows - 4)

  local buf = opts.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = require("custom.ui.buffer").create_raw(false, true)
  end

  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end

  if opts.lines then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
    vim.bo[buf].modifiable = opts.modifiable or false
  else
    vim.bo[buf].modifiable = opts.modifiable or false
  end

  local wc = build_win_config(opts, width, height)
  local win = require("custom.ui.window").open_raw(buf, opts.enter ~= false, wc)

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"

  local id = new_id()
  floats[id] = { buf = buf, win = win, opts = opts }

  -- Only auto-close on BufLeave for non-focusable (popup-style) windows.
  -- Focusable windows (terminals, pickers) must be closed explicitly.
  if not opts.focusable then
    vim.api.nvim_create_autocmd("BufLeave", {
      group = vim.api.nvim_create_augroup("FloatTerm_" .. buf, { clear = false }),
      buffer = buf,
      once = true,
      callback = function()
        M.close(id)
      end,
    })
  end

  -- Default close keymaps — callers (e.g. term.lua) should override these.
  vim.keymap.set("n", "q", function()
    M.close(id)
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    M.close(id)
  end, { buffer = buf, silent = true })

  return id, buf, win
end

--- Close a float by id.
function M.close(id)
  local f = floats[id]
  if not f then
    return
  end

  if vim.api.nvim_win_is_valid(f.win) then
    vim.api.nvim_win_close(f.win, true)
  end
  if vim.api.nvim_buf_is_valid(f.buf) and vim.bo[f.buf].bufhidden ~= "wipe" then
    pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
  end

  if f.opts.on_close then
    pcall(f.opts.on_close)
  end
  floats[id] = nil
end

function M.close_all()
  for id in pairs(floats) do
    M.close(id)
  end
end

function M.set_lines(id, lines)
  local f = floats[id]
  if not f or not vim.api.nvim_buf_is_valid(f.buf) then
    return
  end
  vim.bo[f.buf].modifiable = true
  vim.api.nvim_buf_set_lines(f.buf, 0, -1, false, lines)
  vim.bo[f.buf].modifiable = false
end

function M.resize(id, width, height)
  local f = floats[id]
  if not f or not vim.api.nvim_win_is_valid(f.win) then
    return
  end
  vim.api.nvim_win_set_config(f.win, { width = width, height = height })
end

function M.is_open(id)
  local f = floats[id]
  return f ~= nil and vim.api.nvim_win_is_valid(f.win)
end

function M.get(id)
  return floats[id]
end

-- ─── Named Presets ───────────────────────────────────────────────────────────

function M.dialog(title, lines, opts)
  return M.open(vim.tbl_extend("force", {
    title = title,
    lines = lines,
    width = 0.70,
    height = 0.60,
    position = "center",
  }, opts or {}))
end

function M.popup(lines, opts)
  return M.open(vim.tbl_extend("force", {
    lines = lines,
    width = math.min(60, vim.o.columns - 4),
    height = #lines + 2,
    position = "cursor",
    focusable = false,
  }, opts or {}))
end

function M.fullscreen(title, lines, opts)
  local cols, rows = editor_size()
  return M.open(vim.tbl_extend("force", {
    title = title,
    lines = lines,
    width = cols - 4,
    height = rows - 4,
    position = "center",
    zindex = 100,
  }, opts or {}))
end

return M
