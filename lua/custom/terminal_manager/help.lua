--------------------------------------------------------------------------------
-- custom.terminal_manager/help.lua
-- Floating help window (toggled by pressing ? in the sidebar).
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

local LINES = {
  "",
  "   Terminal Manager — Help   ",
  "",
  "  Sidebar",
  "  ───────────────────────────",
  "  <CR>          select / restart",
  "  j / k         navigate list",
  "  n             new terminal",
  "  d             delete terminal",
  "  r             rename terminal",
  "  R             restart terminal",
  "  <Tab>         focus terminal",
  "  q             close panel",
  "  ?             toggle this help",
  "",
  "  Terminal — insert mode",
  "  ───────────────────────────",
  "  <Esc><Esc>    normal mode",
  "  <C-h/j/k/l>  navigate windows",
  "",
  "  Terminal — normal mode",
  "  ───────────────────────────",
  "  <leader>zT    focus sidebar",
  "",
  "  Global — normal mode",
  "  ───────────────────────────",
  "  <leader>zt    toggle panel",
  "  <leader>zn    new terminal",
  "  <leader>zT    focus sidebar",
  "  <leader>zp    pick profile",
  "  <leader>z1-9  jump to #N",
  "",
  "  Visual mode",
  "  ───────────────────────────",
  "  <leader>zs    send selection",
  "",
  "  Commands",
  "  ───────────────────────────",
  "  :TerminalNew [name]",
  "  :TerminalProfiles",
  "  :TerminalAutomation [name]",
  "",
  "  q / <Esc>  close",
  "",
}

local WIDTH = 38

--- Open the help float, or close it if already open (toggle).
function M.open()
  -- Toggle: close when already visible.
  if utils.win_ok(state.help_win_h) then
    pcall(vim.api.nvim_win_close, state.help_win_h, true)
    state.help_win_h = nil
    return
  end

  local height = math.min(#LINES, vim.o.lines - 4)

  local hbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, LINES)
  utils.buf_opt(hbuf, "modifiable", false)
  utils.buf_opt(hbuf, "filetype", "TermManagerHelp")

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - WIDTH) / 2))

  local hwin = vim.api.nvim_open_win(hbuf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = WIDTH,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
    noautocmd = true,
  })
  state.help_win_h = hwin

  pcall(utils.win_opt, hwin, "winblend", 8)
  pcall(utils.win_opt, hwin, "cursorline", false)
  pcall(utils.win_opt, hwin, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  -- ── Syntax highlights inside the help buffer ─────────────────────────────
  local hns = vim.api.nvim_create_namespace("TermManagerHelpHL")
  for i, line in ipairs(LINES) do
    local r0 = i - 1
    if line:match("^   Terminal Manager") then
      -- Title
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  %a") and not line:match("^  <") then
      -- Section headings (e.g. "  Sidebar", "  Commands")
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  ─") then
      -- Separator lines
      vim.api.nvim_buf_add_highlight(hbuf, hns, "FloatBorder", r0, 0, -1)
    elseif line:match("^  <%S") or line:match("^  :%S") then
      -- Key-binding / command lines: highlight the key token in SpecialKey
      local key_end = (line:find("%s%s") or (#line + 1)) - 1
      vim.api.nvim_buf_add_highlight(hbuf, hns, "SpecialKey", r0, 2, key_end)
    end
  end

  -- ── Close helpers ─────────────────────────────────────────────────────────
  local function close_help()
    pcall(vim.api.nvim_win_close, hwin, true)
    pcall(vim.api.nvim_buf_delete, hbuf, { force = true })
    if state.help_win_h == hwin then
      state.help_win_h = nil
    end
  end

  local ko = { buffer = hbuf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_help, ko)
  vim.keymap.set("n", "<Esc>", close_help, ko)
  vim.keymap.set("n", "?", close_help, ko)

  -- Auto-close when focus moves away (e.g. user clicks the sidebar).
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = hbuf,
    once = true,
    callback = close_help,
  })
end

return M
