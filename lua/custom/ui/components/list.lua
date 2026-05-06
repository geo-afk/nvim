local buffer = require("custom.ui.buffer")
local render = require("custom.ui.render")
local window = require("custom.ui.window")
local state_mod = require("custom.ui.state")

local M = {}

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

function M.open(opts)
  opts = opts or {}
  local lines = opts.lines or {}
  local height = opts.height or math.min(#lines, math.max(1, vim.o.lines - 6))
  local width = opts.width
  if not width then
    width = 1
    for _, line in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(line))
    end
    width = clamp(width + 2, opts.min_width or 24, opts.max_width or math.max(24, vim.o.columns - 8))
  end

  local buf = buffer.create({
    filetype = opts.filetype or "custom_ui_list",
    modifiable = false,
    lines = lines,
  })
  local win = window.open(buf, {
    enter = opts.enter ~= false,
    width = width,
    height = height,
    border = opts.border or "rounded",
    title = opts.title,
    title_pos = opts.title_pos or "center",
    footer = opts.footer,
    footer_pos = opts.footer_pos or "center",
    zindex = opts.zindex or 200,
    noautocmd = opts.noautocmd,
    options = opts.win_options,
  })
  window.configure_float(win, opts.float_options or { cursorline = opts.cursorline == true })

  local ui_state = state_mod.create(opts.id, {
    selection = opts.selection or 1,
    lines = lines,
  })

  local ns = render.ns(opts.ns or ("custom_ui_list_" .. tostring(buf)))
  if opts.highlights then
    render.apply(buf, ns, opts.highlights)
  end

  local function close()
    window.close_pair(win, buf)
    ui_state:close()
  end

  for _, key in ipairs(opts.close_keys or { "q", "<Esc>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, silent = true, nowait = true })
  end

  return { buf = buf, win = win, state = ui_state, close = close }
end

return M
