--------------------------------------------------------------------------------
-- custom/terminal_manager/panel.lua
-- Build / ensure the panel layout.
-- Supports: normal, split, hidden states.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

local function apply_sidebar_opts(win, buf)
  utils.buf_opt(buf, "filetype", "TermManagerSidebar")
  vim.api.nvim_win_set_buf(win, buf)
  utils.win_opt(win, "number", false)
  utils.win_opt(win, "relativenumber", false)
  utils.win_opt(win, "signcolumn", "no")
  utils.win_opt(win, "wrap", false)
  utils.win_opt(win, "cursorline", true)
  utils.win_opt(
    win,
    "winhighlight",
    "Normal:NormalFloat,CursorLine:Visual,SignColumn:NormalFloat,FloatBorder:FloatBorder"
  )
end

local function apply_term_opts(win)
  utils.win_opt(win, "number", false)
  utils.win_opt(win, "relativenumber", false)
  utils.win_opt(win, "signcolumn", "no")
end

M.build = function()
  local cfg = require("custom.terminal_manager").config
  local h = utils.panel_height()
  if h < 1 then
    error("not enough screen space to open the terminal panel")
  end

  vim.cmd("botright " .. h .. "split")
  local right_win = vim.api.nvim_get_current_win()

  vim.cmd("leftabove " .. cfg.sidebar_width .. "vsplit")
  state.ui.sidebar_win = vim.api.nvim_get_current_win()
  state.ui.term_win = right_win

  state.ui.sidebar_buf = require("custom.ui.buffer").create_raw(false, true)
  apply_sidebar_opts(state.ui.sidebar_win, state.ui.sidebar_buf)
  apply_term_opts(state.ui.term_win)

  local sb = state.ui.sidebar_buf
  local opt = function(desc)
    return { buffer = sb, nowait = true, silent = true, desc = desc }
  end

  local function sidebar()
    return require("custom.terminal_manager.sidebar")
  end
  local function help_m()
    return require("custom.terminal_manager.help")
  end
  local function prof_m()
    return require("custom.terminal_manager.profile_manager")
  end
  local function tm()
    return require("custom.terminal_manager")
  end
  local function sp()
    return require("custom.terminal_manager.split")
  end

  vim.keymap.set("n", "<CR>", function()
    sidebar().select()
  end, opt("select / restart"))
  vim.keymap.set("n", "<2-LeftMouse>", function()
    sidebar().select()
  end, opt("select terminal"))
  vim.keymap.set("n", "j", function()
    sidebar().move(1)
  end, opt("next entry"))
  vim.keymap.set("n", "k", function()
    sidebar().move(-1)
  end, opt("prev entry"))
  vim.keymap.set("n", "n", function()
    tm().new_term()
  end, opt("new terminal"))
  vim.keymap.set("n", "d", function()
    sidebar().delete()
  end, opt("delete terminal"))
  vim.keymap.set("n", "r", function()
    sidebar().rename()
  end, opt("rename terminal"))
  vim.keymap.set("n", "R", function()
    sidebar().restart()
  end, opt("restart terminal"))
  vim.keymap.set("n", "P", function()
    prof_m().open()
  end, opt("profile manager"))
  vim.keymap.set("n", "s", function()
    sp().toggle()
  end, opt("toggle split"))
  vim.keymap.set("n", "f", function()
    sidebar().float_selected()
  end, opt("open selected terminal in float mode"))
  vim.keymap.set("n", "q", function()
    tm().close()
  end, opt("close panel"))
  vim.keymap.set("n", "H", function()
    tm().hide()
  end, opt("hide panel"))
  vim.keymap.set("n", "?", function()
    help_m().open()
  end, opt("toggle help"))
  vim.keymap.set("n", "<Tab>", function()
    if state.split_mode and utils.win_ok(state.ui.term_win2) then
      -- Tab cycles between primary and secondary panes
      local cur = vim.api.nvim_get_current_win()
      if cur == state.ui.term_win then
        vim.api.nvim_set_current_win(state.ui.term_win2)
      else
        vim.api.nvim_set_current_win(state.ui.term_win)
      end
    elseif utils.win_ok(state.ui.term_win) then
      vim.api.nvim_set_current_win(state.ui.term_win)
    end
    vim.cmd("startinsert")
  end, opt("focus / cycle terminal panes"))
end

function M.ensure()
  if utils.panel_complete() then
    return true
  end
  if utils.panel_open() then
    require("custom.terminal_manager").close()
  end
  local ok, err = pcall(M.build)
  if not ok then
    vim.notify("TermManager: " .. tostring(err), vim.log.levels.WARN)
    return false
  end
  return utils.panel_complete()
end

return M
