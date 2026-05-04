--------------------------------------------------------------------------------
-- custom/terminal_manager/help.lua
-- Floating help window – updated with all new keys.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}
local WIDTH = 48

local function build_lines()
  local lines = {
    "",
    "   Terminal Manager — Help   ",
    "",
    "  Sidebar",
    "  ─────────────────────────────────────",
    "  <CR>          select terminal",
    "  j / k         navigate list",
    "  n             new terminal",
    "  d             delete terminal",
    "  r             rename terminal",
    "  R             restart terminal",
    "  f             move terminal to float mode",
    "  s             toggle split pane",
    "  P             profile manager",
    "  <Tab>         focus / cycle panes",
    "  H             hide panel",
    "  q             close panel",
    "  ?             toggle this help",
    "",
    "  Terminal — insert mode",
    "  ─────────────────────────────────────",
    "  <Esc><Esc>    normal mode",
    "  <C-h/j/k/l>  navigate windows",
    "  <C-f>         search in terminal",
    "",
    "  Terminal — normal mode",
    "  ─────────────────────────────────────",
    "  <C-f>         search in terminal",
    "  gx / gf       open link / file:line",
    "  gl            list all links",
    "  <leader>zT    focus sidebar",
    "",
    "  Global — normal mode",
    "  ─────────────────────────────────────",
    "  <leader>zt    toggle panel",
    "  <leader>zh    hide panel",
    "  <leader>zf    toggle float / panel mode",
    "  <leader>zn    new terminal",
    "  <leader>zT    focus sidebar",
    "  <leader>zp    pick profile",
    "  <leader>zP    profile manager",
    "  <leader>z|    toggle split pane",
    "  <leader>z<    focus primary pane",
    "  <leader>z>    focus secondary pane",
    "  <leader>zx    swap split terminals",
    "  <leader>z1-9  jump to #N",
    "",
    "  Visual mode",
    "  ─────────────────────────────────────",
    "  <leader>zs    send selection",
    "",
    "  Commands",
    "  ─────────────────────────────────────",
    "  :TerminalNew [name]",
    "  :TerminalProfiles",
    "  :TerminalProfileNew",
    "  :TerminalAutomation [name]",
    "  :TerminalFloat",
    "  :TerminalPanel",
    "  :TerminalSplit",
    "  :TerminalHide",
    "  :TerminalSearch",
    "",
  }

  local km_list = require("custom.terminal_manager.profiles").keymap_list()
  if #km_list > 0 then
    lines[#lines + 1] = "  Profile keymaps"
    lines[#lines + 1] =
      "  ─────────────────────────────────────"
    for _, km in ipairs(km_list) do
      lines[#lines + 1] = string.format("  %-16s %s %s", km.keymap, km.icon or "$", km.name)
    end
    lines[#lines + 1] = ""
  end

  lines[#lines + 1] = "  q / <Esc>  close"
  lines[#lines + 1] = ""
  return lines
end

function M.open()
  if utils.win_ok(state.help_win_h) then
    pcall(vim.api.nvim_win_close, state.help_win_h, true)
    state.help_win_h = nil
    return
  end

  local lines = build_lines()
  local height = math.min(#lines, vim.o.lines - 4)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - WIDTH) / 2))

  local hbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
  utils.buf_opt(hbuf, "modifiable", false)
  utils.buf_opt(hbuf, "filetype", "TermManagerHelp")

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
    zindex = 150,
  })
  state.help_win_h = hwin

  pcall(utils.win_opt, hwin, "winblend", 8)
  pcall(utils.win_opt, hwin, "cursorline", false)
  pcall(utils.win_opt, hwin, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  local hns = vim.api.nvim_create_namespace("TermManagerHelpHL")
  for i, line in ipairs(lines) do
    local r0 = i - 1
    if line:match("^   Terminal Manager") then
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  %a") and not line:match("^  <") and not line:match("^  :") then
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  ─") then
      vim.api.nvim_buf_add_highlight(hbuf, hns, "FloatBorder", r0, 0, -1)
    elseif line:match("^  <%S") or line:match("^  :%S") then
      local key_end = (line:find("%s%s") or (#line + 1)) - 1
      vim.api.nvim_buf_add_highlight(hbuf, hns, "SpecialKey", r0, 2, key_end)
    end
  end

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
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = hbuf,
    once = true,
    callback = close_help,
  })
end

return M
