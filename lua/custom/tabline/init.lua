-- tabline/init.lua
-- Public API, entry point, autocmd coordination, and debounced event queues.

local M = {}
local nvim_utils = require("utils.nvim")

local _config = nil ---@type TablineConfig|nil
local _buffers = nil ---@type table|nil
local _render = nil ---@type table|nil
local _highlights = nil ---@type table|nil
local _mouse = nil ---@type table|nil

-- Debounce timer to prevent micro-stuttering
local redraw_timer = nil

local function debounced_redraw()
  if redraw_timer then
    return
  end
  redraw_timer = vim.uv.new_timer()
  redraw_timer:start(8, 0, vim.schedule_wrap(function()
    vim.cmd("redrawtabline")
    if redraw_timer then
      redraw_timer:close()
      redraw_timer = nil
    end
  end))
end

-- ─── tabline entry point ──────────────────────────────────────────────────

--- Called by Neovim on every tabline redraw
---@return string
function M.render()
  if not _render then
    return ""
  end
  return _render.render()
end

-- ─── buffer navigation ────────────────────────────────────────────────────

--- Smartly switch to a buffer in a regular edit window.
--- If the current window is a sidebar (like explorer), it finds the best edit window.
---@param bufnr integer
function M.switch_to_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  local target_win = current_win

  -- Try to avoid switching in a sidebar/special window
  local ok_explorer, explorer = pcall(require, "custom.explorer")
  if ok_explorer and type(explorer.is_regular_edit_window) == "function" then
    if not explorer.is_regular_edit_window(current_win) then
      local edit_win = explorer.get_edit_win()
      if edit_win then
        target_win = edit_win
      end
    end
  end

  if target_win and vim.api.nvim_win_is_valid(target_win) then
    vim.api.nvim_win_set_buf(target_win, bufnr)
    vim.api.nvim_set_current_win(target_win)
  else
    vim.api.nvim_set_current_buf(bufnr)
  end
end

function M.next_buffer()
  if not _buffers then
    return
  end
  local bufs = _buffers.get_buffers()
  if #bufs == 0 then
    return
  end
  local current = vim.api.nvim_get_current_buf()
  local idx = _buffers.get_index(current) or 0
  local next_b = bufs[(idx % #bufs) + 1]
  if next_b and next_b ~= current then
    M.switch_to_buffer(next_b)
  end
end

function M.prev_buffer()
  if not _buffers then
    return
  end
  local bufs = _buffers.get_buffers()
  if #bufs == 0 then
    return
  end
  local current = vim.api.nvim_get_current_buf()
  local idx = _buffers.get_index(current) or 1
  local prev_b = bufs[((idx - 2) % #bufs) + 1]
  if prev_b and prev_b ~= current then
    M.switch_to_buffer(prev_b)
  end
end

-- ─── buffer management ────────────────────────────────────────────────────

function M.close_buffer(bufnr)
  if not _buffers or not _config then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.close(target, _config.focus_on_close)
  M.invalidate_all_caches(target)
  debounced_redraw()
end

function M.move_buffer_left(bufnr)
  if not _buffers then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_left(target)
  debounced_redraw()
end

function M.move_buffer_right(bufnr)
  if not _buffers then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_right(target)
  debounced_redraw()
end

-- ─── cache invalidation coordination ──────────────────────────────────────

--- Bust all caches for a specific buffer or the entire system
---@param bufnr integer|nil
function M.invalidate_all_caches(bufnr)
  -- 1. Invalidate name cache
  if _render then
    _render.invalidate_name_cache()
  end
  -- 2. Invalidate buffer sync cache
  if _buffers then
    _buffers.invalidate_cache()
  end
  -- 3. Invalidate project detection cache
  local ok_proj, proj = pcall(require, "custom.tabline.projects")
  if ok_proj then
    proj.invalidate_cache(bufnr)
  end
end

-- ─── autocmds ─────────────────────────────────────────────────────────────

local function setup_autocmds()
  local grp = nvim_utils.augroup("TablinePlugin")

  -- Core buffer addition and deletion triggers cache busting
  nvim_utils.autocmd({
    "BufAdd",
    "BufDelete",
    "BufFilePost",
    "BufReadPost",
    "BufNewFile",
    "TabClosed",
    "TermOpen",
  }, {
    group = grp,
    callback = function(event)
      M.invalidate_all_caches(event.buf)
      debounced_redraw()
    end,
  })

  -- Redraw visual states safely on user triggers
  nvim_utils.autocmd({
    "BufEnter",
    "BufModifiedSet",
  }, {
    group = grp,
    callback = function()
      debounced_redraw()
    end,
  })

  -- Re-apply highlights whenever the colorscheme changes
  nvim_utils.autocmd("ColorScheme", {
    group = grp,
    callback = function()
      if _highlights then
        _highlights.setup()
      end
      debounced_redraw()
    end,
  })
end

-- ─── user commands ────────────────────────────────────────────────────────

local function setup_commands()
  local opts = { force = true }

  nvim_utils.command("TablineNext", M.next_buffer, vim.tbl_extend("force", opts, { desc = "TabLine: next buffer" }))
  nvim_utils.command("TablinePrev", M.prev_buffer, vim.tbl_extend("force", opts, { desc = "TabLine: prev buffer" }))

  nvim_utils.command("TablineClose", function(o)
    M.close_buffer(o.args ~= "" and tonumber(o.args) or nil)
  end, vim.tbl_extend("force", opts, { nargs = "?", desc = "TabLine: close buffer" }))

  nvim_utils.command(
    "TablineMoveLeft",
    M.move_buffer_left,
    vim.tbl_extend("force", opts, { desc = "TabLine: move buffer left" })
  )
  nvim_utils.command(
    "TablineMoveRight",
    M.move_buffer_right,
    vim.tbl_extend("force", opts, { desc = "TabLine: move buffer right" })
  )
end

-- ─── setup ────────────────────────────────────────────────────────────────

---@param user_config table|nil
function M.setup(user_config)
  local config_mod = require("custom.tabline.config")
  _highlights = require("custom.tabline.highlights")
  _buffers = require("custom.tabline.buffers")
  _render = require("custom.tabline.render")
  _mouse = require("custom.tabline.mouse")

  _config = config_mod.apply(user_config)

  if _highlights then
    _highlights.setup()
  end
  if _render then
    _render.setup(_config)
  end
  if _mouse then
    _mouse.setup(_config)
  end

  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.require'custom.tabline'.render()"

  -- Apply premium keymaps
  local map = vim.keymap.set
  if _config.keymaps.next then
    map("n", _config.keymaps.next, function()
      M.next_buffer()
    end, { desc = "Tabline: next buffer" })
  end
  if _config.keymaps.prev then
    map("n", _config.keymaps.prev, function()
      M.prev_buffer()
    end, { desc = "Tabline: prev buffer" })
  end
  if _config.keymaps.close then
    map("n", _config.keymaps.close, function()
      M.close_buffer()
    end, { desc = "Tabline: close buffer" })
  end

  setup_autocmds()
  setup_commands()
end

--- Allow overriding individual highlight groups after setup.
---@param name string
---@param opts table
function M.set_highlight(name, opts)
  if _highlights then
    _highlights.override(name, opts)
  end
end

return M
