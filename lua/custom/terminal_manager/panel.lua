--------------------------------------------------------------------------------
-- custom.terminal_manager/panel.lua
-- Builds the two-pane layout (sidebar + terminal window) and wires up all
-- sidebar buffer-local keymaps.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

--- Build the panel from scratch.
--- Must only be called when the panel is fully closed.
M.build = function()
  local cfg = require("custom.terminal_manager").config
  local h = utils.panel_height()
  if h < 1 then
    error("not enough screen space to open the terminal panel")
  end

  -- 1. Full-width horizontal split pinned to the bottom.
  vim.cmd("botright " .. h .. "split")
  local right_win = vim.api.nvim_get_current_win()

  -- 2. Narrow sidebar split on the LEFT of that new window.
  --    After `leftabove vsplit` the left window (sidebar) is current.
  vim.cmd("leftabove " .. cfg.sidebar_width .. "vsplit")
  state.ui.sidebar_win = vim.api.nvim_get_current_win()
  state.ui.term_win = right_win

  -- 3. Sidebar scratch buffer.
  state.ui.sidebar_buf = vim.api.nvim_create_buf(false, true)
  utils.buf_opt(state.ui.sidebar_buf, "filetype", "TermManagerSidebar")
  vim.api.nvim_win_set_buf(state.ui.sidebar_win, state.ui.sidebar_buf)

  -- 4. Sidebar window appearance.
  utils.win_opt(state.ui.sidebar_win, "number", false)
  utils.win_opt(state.ui.sidebar_win, "relativenumber", false)
  utils.win_opt(state.ui.sidebar_win, "signcolumn", "no")
  utils.win_opt(state.ui.sidebar_win, "wrap", false)
  utils.win_opt(state.ui.sidebar_win, "cursorline", true)
  utils.win_opt(
    state.ui.sidebar_win,
    "winhighlight",
    "Normal:NormalFloat,CursorLine:Visual,SignColumn:NormalFloat,FloatBorder:FloatBorder"
  )

  -- 5. Terminal window appearance (minimal decorations).
  utils.win_opt(state.ui.term_win, "number", false)
  utils.win_opt(state.ui.term_win, "relativenumber", false)
  utils.win_opt(state.ui.term_win, "signcolumn", "no")

  -- 6. Buffer-local sidebar keymaps (automatically cleared with the buffer).
  local sb = state.ui.sidebar_buf
  local opt = function(desc)
    return { buffer = sb, nowait = true, silent = true, desc = desc }
  end

  -- Lazy-load the action modules to avoid circular deps at this require point.
  local function sidebar()
    return require("custom.terminal_manager.sidebar")
  end
  local function help_mod()
    return require("custom.terminal_manager.help")
  end
  local function tm()
    return require("custom.terminal_manager")
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
  vim.keymap.set("n", "q", function()
    tm().close()
  end, opt("close panel"))
  vim.keymap.set("n", "?", function()
    help_mod().open()
  end, opt("toggle help"))
  vim.keymap.set("n", "<Tab>", function()
    if utils.win_ok(state.ui.term_win) then
      vim.api.nvim_set_current_win(state.ui.term_win)
      vim.cmd("startinsert")
    end
  end, opt("focus terminal"))
end

--- Ensure the panel is fully built.
--- If the panel is partially open (one window closed externally), it is torn
--- down and rebuilt cleanly.
--- Returns true when the panel is ready, false on error.
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
