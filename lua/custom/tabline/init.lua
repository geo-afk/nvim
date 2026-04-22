-- tabline/init.lua
-- Public API and entry point.
--
-- Users call:
--   require("custom.tabline").setup({ ... })
--
-- Public functions (usable in keymaps or commands):
--   require("custom.tabline").next_buffer()
--   require("custom.tabline").prev_buffer()
--   require("custom.tabline").close_buffer()
--   require("custom.tabline").move_buffer_left()
--   require("custom.tabline").move_buffer_right()
--
local M = {}
local nvim_utils = require("utils.nvim")

local _config = nil ---@type TablineConfig|nil
local _buffers = nil ---@type table|nil
local _render = nil ---@type table|nil
local _highlights = nil ---@type table|nil
local _mouse = nil ---@type table|nil

-- ─── tabline entry point ──────────────────────────────────────────────────

--- Called by Neovim on every tabline redraw via:
---   vim.o.tabline = "%!v:lua.require'tabline'.render()"
---@return string
function M.render()
  if not _render then
    return ""
  end
  return _render.render()
end

-- ─── buffer navigation ────────────────────────────────────────────────────

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
    vim.api.nvim_set_current_buf(next_b)
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
  -- FIX #8: Default to idx=1 when current is not in the list so that
  -- ((1-2) % n)+1 = n correctly wraps to the last buffer.
  local idx = _buffers.get_index(current) or 1
  local prev_b = bufs[((idx - 2) % #bufs) + 1]
  if prev_b and prev_b ~= current then
    vim.api.nvim_set_current_buf(prev_b)
  end
end

-- ─── buffer management ────────────────────────────────────────────────────

function M.close_buffer(bufnr)
  if not _buffers or not _config then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.close(target, _config.focus_on_close)
end

function M.move_buffer_left(bufnr)
  if not _buffers then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_left(target)
  vim.cmd("redrawtabline")
end

function M.move_buffer_right(bufnr)
  if not _buffers then
    return
  end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_right(target)
  vim.cmd("redrawtabline")
end

-- ─── autocmds ─────────────────────────────────────────────────────────────

local function setup_autocmds()
  local grp = nvim_utils.augroup("TablinePlugin")

  -- Standard redraw events
  nvim_utils.autocmd({
    "BufAdd",
    "BufDelete",
    "BufEnter",
    "BufModifiedSet",
    "TabClosed",
  }, {
    group = grp,
    callback = function()
      vim.schedule(function()
        vim.cmd("redrawtabline")
      end)
    end,
  })

  -- FIX #9: BufReadPost / BufNewFile / BufFilePost must bust the name cache
  -- synchronously, then schedule the visual redraw.
  nvim_utils.autocmd({
    "BufReadPost",
    "BufNewFile",
    "BufFilePost",
  }, {
    group = grp,
    callback = function()
      if _render then
        _render.invalidate_name_cache()
      end
      vim.schedule(function()
        vim.cmd("redrawtabline")
      end)
    end,
  })

  -- Re-apply highlights whenever the colorscheme changes.
  nvim_utils.autocmd("ColorScheme", {
    group = grp,
    callback = function()
      if _highlights then
        _highlights.setup()
      end
    end,
  })
end

-- ─── user commands ────────────────────────────────────────────────────────

local function setup_commands()
  -- FIX #10: force=true so re-calling setup() does not raise
  -- "command already exists" errors.
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

  local map = vim.keymap.set
  map("n", "<Tab>", function()
    M.next_buffer()
  end, { desc = "Next buffer" })
  map("n", "<S-Tab>", function()
    M.prev_buffer()
  end, { desc = "Prev buffer" })
  map("n", "<A-c>", function()
    M.close_buffer()
  end, { desc = "Close buffer" })

  setup_autocmds() -- augroup is cleared then recreated → idempotent
  setup_commands() -- force=true → idempotent
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
