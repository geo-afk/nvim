local list = require("custom.ui.components.list")

local M = {}

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

function M.open(opts)
  opts = opts or {}
  local items = opts.items or {}
  local format = opts.format_item or tostring
  local lines = {}
  for _, item in ipairs(items) do
    lines[#lines + 1] = "  " .. format(item)
  end

  opts.lines = opts.lines or lines
  opts.cursorline = opts.cursorline ~= false
  local ui = list.open(opts)
  local selected = clamp(opts.selection or 1, 1, math.max(1, #items))
  ui.state:set("selection", selected)

  local function move(delta)
    selected = clamp(selected + delta, 1, math.max(1, #items))
    ui.state:set("selection", selected)
    if vim.api.nvim_win_is_valid(ui.win) then
      pcall(vim.api.nvim_win_set_cursor, ui.win, { selected, 0 })
    end
    if opts.on_move then
      opts.on_move(items[selected], selected, ui)
    end
  end

  local function confirm()
    local item = items[selected]
    ui.close()
    if opts.on_confirm then
      vim.schedule(function()
        opts.on_confirm(item, selected)
      end)
    end
  end

  local map_opts = { buffer = ui.buf, silent = true, nowait = true }
  vim.keymap.set("n", "<CR>", confirm, map_opts)
  vim.keymap.set("n", "j", function()
    move(1)
  end, map_opts)
  vim.keymap.set("n", "k", function()
    move(-1)
  end, map_opts)
  vim.keymap.set("n", "<Down>", function()
    move(1)
  end, map_opts)
  vim.keymap.set("n", "<Up>", function()
    move(-1)
  end, map_opts)

  pcall(vim.api.nvim_win_set_cursor, ui.win, { selected, 0 })
  return ui
end

return M
