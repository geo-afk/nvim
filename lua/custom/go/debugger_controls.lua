-- debugger_controls.lua — interactive floating control bar for Go debugger
local M = {}

local S = {
  win = nil,
  buf = nil,
  index = 1, -- current selected control
}

local CONTROLS = {
  { icon = " 󰐊 ", action = "continue", hl = "GoDbgBtnContinue", desc = "Continue (c)" },
  { icon = " 󰆹 ", action = "step_over", hl = "GoDbgBtnStep", desc = "Next (n)" },
  { icon = " 󰆽 ", action = "step_into", hl = "GoDbgBtnStep", desc = "Step In (i)" },
  { icon = " 󰆾 ", action = "step_out", hl = "GoDbgBtnStep", desc = "Step Out (o)" },
  { icon = " 󰏤 ", action = "pause", hl = "GoDbgBtnPause", desc = "Pause (p)" },
  { icon = " 󰓛 ", action = "stop", hl = "GoDbgBtnStop", desc = "Stop (s)" },
  { icon = " 󰑓 ", action = "restart", hl = "GoDbgBtnRestart", desc = "Restart (r)" },
}

local NS = vim.api.nvim_create_namespace("go_dbg_controls")

local function sb_width()
  return math.max(35, math.floor(vim.o.columns * 0.22))
end

local function render()
  if not S.buf or not vim.api.nvim_buf_is_valid(S.buf) then
    return
  end

  local line = ""
  for _, c in ipairs(CONTROLS) do
    line = line .. c.icon
  end

  vim.bo[S.buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, { line })
  vim.bo[S.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(S.buf, NS, 0, -1)

  local col = 0
  for i, c in ipairs(CONTROLS) do
    local end_col = col + #c.icon
    local hl = c.hl
    if i == S.index then
      hl = "CursorLine" -- highlight selected
    end

    require("custom.ui.render").set_extmark(S.buf, NS, 0, col, {
      end_col = end_col,
      hl_group = hl,
      priority = 100,
    })

    if i == S.index and S.win and vim.api.nvim_win_is_valid(S.win) then
      -- Update title with description of selected action
      pcall(vim.api.nvim_win_set_config, S.win, { title = " " .. c.desc .. " " })
    end

    col = end_col
  end
end

local function execute_current()
  local ctrl = CONTROLS[S.index]
  if ctrl then
    local dbg = require("custom.go.debugger")
    if dbg[ctrl.action] then
      dbg[ctrl.action]()
    end
  end
end

function M.open()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_set_current_win(S.win)
    return
  end

  S.buf = require("custom.ui.buffer").create_raw(false, true)
  vim.bo[S.buf].buftype = "nofile"
  vim.bo[S.buf].swapfile = false
  vim.bo[S.buf].bufhidden = "wipe"
  vim.bo[S.buf].filetype = "godebug_controls"

  local width = 0
  for _, c in ipairs(CONTROLS) do
    width = width + #c.icon
  end

  local col = vim.o.columns - sb_width() - width - 4
  S.win = require("custom.ui.window").open_raw(S.buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = 1,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Debug ",
    title_pos = "center",
    zindex = 150,
  })

  vim.wo[S.win].winhl = "Normal:NormalFloat,FloatBorder:DiagnosticInfo"

  -- Keymaps
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = S.buf, silent = true, nowait = true })
  end

  map("h", function()
    S.index = S.index > 1 and S.index - 1 or #CONTROLS
    render()
  end)
  map("l", function()
    S.index = S.index < #CONTROLS and S.index + 1 or 1
    render()
  end)
  map("<Left>", function()
    S.index = S.index > 1 and S.index - 1 or #CONTROLS
    render()
  end)
  map("<Right>", function()
    S.index = S.index < #CONTROLS and S.index + 1 or 1
    render()
  end)
  map("<CR>", execute_current)
  map("k", execute_current) -- user requested 'k'
  map("q", M.close)
  map("<Esc>", function()
    M.close()
  end)

  render()
end

function M.close()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_win_close(S.win, true)
  end
  S.win = nil
  S.buf = nil
end

function M.is_open()
  return S.win and vim.api.nvim_win_is_valid(S.win)
end

function M.is_focused()
  return S.win and vim.api.nvim_get_current_win() == S.win
end

return M
