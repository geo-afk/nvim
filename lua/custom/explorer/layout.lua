-- custom/explorer/layout.lua
--
-- Owns the screen geometry and lifecycle of every explorer region. The tree is
-- a normal sidebar split; the fixed header is a borderless overlay occupying
-- the tree's reserved header rows. Both regions share one authoritative width.

local S = require("custom.explorer.state")

local api = vim.api
local M = {}
local creating_header = false

M.HEADER_HEIGHT = 3

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

function M.geometry()
  if not valid_win(S.win) then
    return nil
  end
  local pos = api.nvim_win_get_position(S.win)
  return {
    relative = "editor",
    row = pos[1],
    col = pos[2],
    width = math.max(api.nvim_win_get_width(S.win), 1),
    height = M.HEADER_HEIGHT,
    style = "minimal",
    border = "none",
    focusable = S.search_active,
    zindex = 60,
  }
end

local function make_header_buf()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  api.nvim_set_option_value("buflisted", false, { buf = buf })
  api.nvim_set_option_value("swapfile", false, { buf = buf })
  api.nvim_set_option_value("filetype", "explorer_search", { buf = buf })
  return buf
end

local function apply_header_options(win)
  if not valid_win(win) then
    return
  end
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.statusline = ""
  wo.winbar = ""
  wo.wrap = false
  wo.spell = false
  wo.list = false
  wo.cursorline = false
  wo.fillchars = "eob: "
  wo.winhighlight = table.concat({
    "Normal:ExplorerNormal",
    "NormalNC:ExplorerNormal",
    "EndOfBuffer:ExplorerNormal",
  }, ",")
  wo.winfixbuf = true
end

function M.ensure()
  if S.closing or creating_header then
    return nil, S.search_buf
  end
  if not valid_buf(S.search_buf) then
    S.search_buf = make_header_buf()
  end

  local geometry = M.geometry()
  if not geometry then
    return nil, S.search_buf
  end

  if valid_win(S.search_win) then
    api.nvim_win_set_config(S.search_win, geometry)
  else
    -- nvim_open_win() can synchronously fire WinEnter. Guard against the
    -- WinEnter layout synchronizer re-entering ensure() before the returned
    -- window id has been assigned, otherwise a second orphan float is created.
    creating_header = true
    local ok, win = pcall(api.nvim_open_win, S.search_buf, false, geometry)
    creating_header = false
    if not ok then
      return nil, S.search_buf
    end
    S.search_win = win
  end
  apply_header_options(S.search_win)
  return S.search_win, S.search_buf
end

function M.sync()
  if S.closing then
    return nil, S.search_buf
  end
  if not valid_win(S.search_win) then
    return M.ensure()
  end
  local geometry = M.geometry()
  if geometry then
    api.nvim_win_set_config(S.search_win, geometry)
    apply_header_options(S.search_win)
  end
  return S.search_win, S.search_buf
end

function M.close(opts)
  opts = opts or {}
  local header_win = S.search_win
  S.search_win = nil

  if valid_win(header_win) then
    local closed = pcall(api.nvim_win_close, header_win, true)
    if not closed and valid_win(header_win) then
      -- Closing the current float can be rejected while a mapping/autocmd is
      -- still executing. Keep the concrete id and retry outside that context;
      -- never leave a live, non-focusable window behind after dropping state.
      vim.schedule(function()
        if valid_win(header_win) then
          pcall(api.nvim_win_close, header_win, true)
        end
        pcall(vim.cmd, "redraw!")
      end)
    end
  end

  if opts.wipe and valid_buf(S.search_buf) then
    local buf = S.search_buf
    S.search_buf = nil
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

function M.is_owned_window(win)
  return win == S.win or win == S.search_win
end

return M
