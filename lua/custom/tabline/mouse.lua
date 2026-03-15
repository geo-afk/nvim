-- tabline/mouse.lua
-- Mouse click handlers for the tabline.
--
-- HOW TABLINE CLICKS WORK
-- ───────────────────────
-- Neovim's tabline format string supports:
--
--   %{N}@{FuncName}@{label}%X
--
-- When the user clicks on `label`:
--   FuncName(N, clicks, button, modifier)
--     N        - the minwid integer embedded in the format
--     clicks   - number of clicks (1, 2 …)
--     button   - 'l' left  'm' middle  'r' right
--     modifier - modifier keys ('C' ctrl, 'S' shift, 'A' alt, ' ' none)
--
-- Because the function name is evaluated as a Vimscript expression we
-- register the handlers as plain globals (_G.*), which lets us use
-- @v:lua.TablineHandleClick@ in the format string.  This is the same
-- technique used by mini.tabline, cokeline.nvim and others.

local M = {}

local _config = nil  -- set by M.setup()

function M.setup(config)
  _config = config
end

-- ─── handlers ─────────────────────────────────────────────────────────────

--- Left / middle click on the buffer label area.
---@param bufnr    integer
---@param clicks   integer
---@param button   string
---@param modifier string
function M.handle_click(bufnr, clicks, button, modifier)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  if button == "m" then
    -- Middle click → close
    local buffers = require("custom.tabline.buffers")
    local focus = _config and _config.focus_on_close or "left"
    buffers.close(bufnr, focus)
  elseif button == "l" then
    -- Left click → switch
    -- Avoid switching when already on this buffer (no flicker)
    if vim.api.nvim_get_current_buf() ~= bufnr then
      vim.api.nvim_set_current_buf(bufnr)
    end
  end
  -- Right click: intentionally ignored (let the terminal handle it)
end

--- Left / middle click on the × close button.
---@param bufnr    integer
---@param clicks   integer
---@param button   string
---@param modifier string
function M.handle_close(bufnr, clicks, button, modifier)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  if button == "l" or button == "m" then
    local buffers = require("custom.tabline.buffers")
    local focus = _config and _config.focus_on_close or "left"
    buffers.close(bufnr, focus)
  end
end

-- ─── global registration ──────────────────────────────────────────────────
-- Register as Vim-accessible globals so the tabline format string can use:
--   %{bufnr}@v:lua.TablineHandleClick@  and
--   %{bufnr}@v:lua.TablineHandleClose@

_G.TablineHandleClick = M.handle_click
_G.TablineHandleClose = M.handle_close

return M
