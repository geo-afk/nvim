--------------------------------------------------------------------------------
-- custom/terminal_manager/float.lua
-- Floating-mode layout for the terminal manager.
--------------------------------------------------------------------------------

local floating = require("custom.float_term.floating")
local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

local function close_panel_windows()
  if utils.win_ok(state.help_win_h) then
    pcall(vim.api.nvim_win_close, state.help_win_h, true)
    state.help_win_h = nil
  end
  if state.split_mode and utils.win_ok(state.ui.term_win2) then
    pcall(vim.api.nvim_win_close, state.ui.term_win2, true)
  end
  for _, win in ipairs({ state.ui.sidebar_win, state.ui.term_win }) do
    if utils.win_ok(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  utils.reset_panel_handles()
end

local function ensure_buf(t)
  if not utils.buf_ok(t.buf) then
    t.buf = require("custom.ui.buffer").create_raw(false, false)
    utils.buf_opt(t.buf, "bufhidden", "hide")
  end
end

local function title_for(t)
  local profile = t.profile or {}
  local icon = profile.icon or "$"
  local name = t.name or "terminal"
  local prof = profile.name and (" [" .. profile.name .. "]") or ""
  return string.format("%s %s%s", icon, name, prof)
end

local function focus_float()
  if utils.win_ok(state.ui.float_win) then
    vim.api.nvim_set_current_win(state.ui.float_win)
    vim.cmd("startinsert")
  end
end

function M.open(t)
  if not t then
    return false
  end

  close_panel_windows()
  ensure_buf(t)

  if state.float_id and floating.is_open(state.float_id) then
    floating.close(state.float_id)
  elseif utils.win_ok(state.ui.float_win) then
    pcall(vim.api.nvim_win_close, state.ui.float_win, true)
  end
  utils.reset_float_handles()

  local cfg = require("custom.terminal_manager").config.float or {}
  -- Declare before constructing callbacks so on_close captures this local,
  -- not an unresolved global from the initializer's scope.
  local float_id, win
  float_id, _, win = floating.open({
    buf = t.buf,
    enter = true,
    focusable = true,
    modifiable = true,
    width = cfg.width or 0.80,
    height = cfg.height or 0.80,
    border = cfg.border,
    title = title_for(t),
    title_pos = cfg.title_pos or "center",
    zindex = cfg.zindex or 60,
    on_close = function()
      if state.ui.float_win == win then
        utils.reset_float_handles()
      end
    end,
  })

  state.ui.float_win = win
  state.float_id = float_id
  state.active_id = t.id
  state.panel_hidden = false

  if cfg.winblend then
    pcall(utils.win_opt, win, "winblend", cfg.winblend)
  end
  pcall(utils.win_opt, win, "cursorline", false)
  pcall(utils.win_opt, win, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  require("custom.terminal_manager.terminal").show_in_win(t, win)
  require("custom.terminal_manager.winbar").update_all()
  focus_float()
  return true
end

function M.close()
  if state.float_id and floating.is_open(state.float_id) then
    floating.close(state.float_id)
  elseif utils.win_ok(state.ui.float_win) then
    pcall(vim.api.nvim_win_close, state.ui.float_win, true)
  end
  utils.reset_float_handles()
end

function M.focus()
  focus_float()
end

return M
