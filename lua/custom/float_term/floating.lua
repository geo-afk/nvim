--- custom/float_term/floating.lua
--- Floating Window Factory — creates, manages, and destroys floating
--- windows with consistent styling, focus trapping, and auto-close behaviour.

local M = {}

-- ─── Registry of open floats ─────────────────────────────────────────────────

local floats = {} -- id -> { buf, win, opts }
local id_seq = 0

local function new_id()
  id_seq = id_seq + 1
  return id_seq
end

-- ─── Geometry Helpers ────────────────────────────────────────────────────────

local function editor_size()
  return vim.o.columns, vim.o.lines - vim.o.cmdheight - 1
end

local function center_pos(width, height)
  local cols, rows = editor_size()
  return {
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
  }
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

--- Fraction (0 < n < 1) → percentage of total; integer ≥ 1 → absolute.
local function resolve_size(spec, total)
  if spec > 0 and spec < 1 then
    return math.floor(total * spec)
  end
  return math.floor(spec)
end

-- ─── Float Spec ──────────────────────────────────────────────────────────────
-- opts accepted by M.open():
--   position   "center"|"top"|"bottom"|"cursor"|{row,col}   default: "center"
--   width      number (abs or 0–1 fraction)                  default: 0.7
--   height     number (abs or 0–1 fraction)                  default: 0.6
--   border     string|nil   default: nil (inherits vim.o.winborder in 0.12+)
--   title      string
--   title_pos  "left"|"center"|"right"                       default: "center"
--   footer     string
--   footer_pos "left"|"center"|"right"                       default: "center"
--   focusable  boolean                                        default: true
--   enter      boolean                                        default: true
--   buf        integer      use existing buffer
--   filetype   string
--   lines      string[]     set buffer lines
--   modifiable boolean                                        default: false
--   on_close   fn()
--   style      "minimal"|nil
--   zindex     number                                         default: 50

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
    local p = center_pos(width, height)
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
    local p = center_pos(width, height)
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
--- @param opts table  (see spec above)
--- @return integer id, integer buf, integer win
function M.open(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, DEFAULTS)

  local cols, rows = editor_size()
  local width = clamp(resolve_size(opts.width, cols), 10, cols - 4)
  local height = clamp(resolve_size(opts.height, rows), 3, rows - 4)

  -- Buffer
  local buf = opts.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
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

  -- Window
  local wc = build_win_config(opts, width, height)
  local win = vim.api.nvim_open_win(buf, opts.enter ~= false, wc)

  -- Window options
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"

  -- Register
  local id = new_id()
  floats[id] = { buf = buf, win = win, opts = opts }

  -- Auto-close on BufLeave when not focusable
  if not opts.focusable then
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      once = true,
      callback = function()
        M.close(id)
      end,
    })
  end

  -- Default close keymaps (callers may override on the same buffer)
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

--- Close all open floats.
function M.close_all()
  for id in pairs(floats) do
    M.close(id)
  end
end

--- Update a float's content.
function M.set_lines(id, lines)
  local f = floats[id]
  if not f or not vim.api.nvim_buf_is_valid(f.buf) then
    return
  end
  vim.bo[f.buf].modifiable = true
  vim.api.nvim_buf_set_lines(f.buf, 0, -1, false, lines)
  vim.bo[f.buf].modifiable = false
end

--- Resize a float.
function M.resize(id, width, height)
  local f = floats[id]
  if not f or not vim.api.nvim_win_is_valid(f.win) then
    return
  end
  vim.api.nvim_win_set_config(f.win, { width = width, height = height })
end

--- Check if a float is still open.
function M.is_open(id)
  local f = floats[id]
  return f ~= nil and vim.api.nvim_win_is_valid(f.win)
end

--- Get the buf/win table of a float.
function M.get(id)
  return floats[id]
end

-- ─── Named Presets ───────────────────────────────────────────────────────────

--- Open a large centred dialog.
function M.dialog(title, lines, opts)
  return M.open(vim.tbl_extend("force", {
    title = title,
    lines = lines,
    width = 0.70,
    height = 0.60,
    position = "center",
  }, opts or {}))
end

--- Open a small popup near the cursor.
function M.popup(lines, opts)
  return M.open(vim.tbl_extend("force", {
    lines = lines,
    width = math.min(60, vim.o.columns - 4),
    height = #lines + 2,
    position = "cursor",
  }, opts or {}))
end

--- Fullscreen overlay.
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
