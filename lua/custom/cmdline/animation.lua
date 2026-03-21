-- nvim-cmdline/animation.lua
-- Slide-in / slide-out animations for floating windows via libuv timers.
-- vim.uv (Neovim 0.10+) preferred; falls back to vim.loop (0.9).

local M = {}

local uv = vim.uv or vim.loop

-- ---------------------------------------------------------------------------
-- Easing
-- ---------------------------------------------------------------------------

local function ease_out_cubic(t)
  return 1 - (1 - t) ^ 3
end
local function ease_in_cubic(t)
  return t ^ 3
end

-- ---------------------------------------------------------------------------
-- Core runner
-- ---------------------------------------------------------------------------

---Run `on_step` every `interval` ms for `steps` ticks, then `on_done`.
---@param steps    integer
---@param interval integer  ms
---@param on_step  fun(step:integer, t:number)
---@param on_done  fun()?
local function run(steps, interval, on_step, on_done)
  local step = 0
  local timer = uv.new_timer()
  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      step = step + 1
      on_step(step, math.min(step / steps, 1.0))
      if step >= steps then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
        if on_done then
          on_done()
        end
      end
    end)
  )
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Slide a window in from below its target row.
---@param win_id     integer
---@param target_row integer  final row
---@param opts       table?   { steps=4, duration_ms=80, offset=4 }
---@param callback   fun()?
function M.slide_in(win_id, target_row, opts, callback)
  if type(win_id) ~= "number" or not vim.api.nvim_win_is_valid(win_id) then
    if callback then
      callback()
    end
    return
  end

  opts = type(opts) == "table" and opts or {}
  local steps = math.max(1, type(opts.steps) == "number" and opts.steps or 4)
  local dur = math.max(1, type(opts.duration_ms) == "number" and opts.duration_ms or 80)
  local offset = math.max(0, type(opts.offset) == "number" and opts.offset or 4)
  local interval = math.max(1, math.floor(dur / steps))

  local start_row = target_row + offset

  -- Move to starting position immediately (before any tick fires)
  pcall(vim.api.nvim_win_set_config, win_id, { row = start_row })

  run(steps, interval, function(_, t)
    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end
    local row = math.floor(start_row + (target_row - start_row) * ease_out_cubic(t))
    pcall(vim.api.nvim_win_set_config, win_id, { row = row })
  end, function()
    -- Snap to exact final position
    if vim.api.nvim_win_is_valid(win_id) then
      pcall(vim.api.nvim_win_set_config, win_id, { row = target_row })
    end
    if callback then
      callback()
    end
  end)
end

---Slide a window out downward, then call callback.
---@param win_id   integer
---@param opts     table?   { steps=3, duration_ms=60, offset=4 }
---@param callback fun()    called after the animation ends
function M.slide_out(win_id, opts, callback)
  if type(win_id) ~= "number" or not vim.api.nvim_win_is_valid(win_id) then
    if callback then
      callback()
    end
    return
  end

  opts = type(opts) == "table" and opts or {}
  local steps = math.max(1, type(opts.steps) == "number" and opts.steps or 3)
  local dur = math.max(1, type(opts.duration_ms) == "number" and opts.duration_ms or 60)
  local offset = math.max(0, type(opts.offset) == "number" and opts.offset or 4)
  local interval = math.max(1, math.floor(dur / steps))

  -- Read starting row; if this fails the window is already gone
  local ok, cfg = pcall(vim.api.nvim_win_get_config, win_id)
  if not ok then
    if callback then
      callback()
    end
    return
  end

  local start_row = type(cfg.row) == "number" and cfg.row or 0
  local target_row = start_row + offset

  run(steps, interval, function(_, t)
    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end
    local row = math.floor(start_row + (target_row - start_row) * ease_in_cubic(t))
    pcall(vim.api.nvim_win_set_config, win_id, { row = row })
  end, function()
    if callback then
      callback()
    end
  end)
end

return M
