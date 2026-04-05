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

---Run `on_step` every `interval` ms for `steps` ticks, then call `on_done`.
---@param steps    integer
---@param interval integer  ms
---@param on_step  fun(step:integer, t:number)
---@param on_done  fun()?
local function run(steps, interval, on_step, on_done)
  if type(steps) ~= "number" or steps <= 0 or type(interval) ~= "number" or interval <= 0 then
    if on_done then
      on_done()
    end
    return
  end

  local step = 0
  local timer = uv.new_timer()
  if not timer then
    if on_done then
      on_done()
    end
    return
  end

  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      step = step + 1

      if on_step then
        pcall(on_step, step, math.min(step / steps, 1.0))
      end

      if step >= steps then
        if not timer:is_closing() then
          timer:stop()
          timer:close()
        end
        if on_done then
          pcall(on_done)
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

  local cfg_ok, cfg = pcall(vim.api.nvim_win_get_config, win_id)
  local relative = (cfg_ok and type(cfg.relative) == "string" and cfg.relative ~= "") and cfg.relative or "editor"
  local col = (cfg_ok and type(cfg.col) == "number") and cfg.col or 0

  local start_row = target_row + offset

  -- Move to starting position immediately
  local ok = pcall(vim.api.nvim_win_set_config, win_id, { relative = relative, row = start_row, col = col })
  if not ok then
    if callback then
      callback()
    end
    return
  end

  run(steps, interval, function(_, t)
    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end
    local row = math.floor(start_row + (target_row - start_row) * ease_out_cubic(t))
    pcall(vim.api.nvim_win_set_config, win_id, { relative = relative, row = row, col = col })
  end, function()
    -- Snap to exact final position
    if vim.api.nvim_win_is_valid(win_id) then
      pcall(vim.api.nvim_win_set_config, win_id, { relative = relative, row = target_row, col = col })
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

  local ok, cfg = pcall(vim.api.nvim_win_get_config, win_id)
  if not ok or type(cfg.row) ~= "number" then
    if callback then
      callback()
    end
    return
  end

  local start_row = cfg.row
  local target_row = start_row + offset
  local relative = (type(cfg.relative) == "string" and cfg.relative ~= "") and cfg.relative or "editor"
  local col = type(cfg.col) == "number" and cfg.col or 0

  run(steps, interval, function(_, t)
    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end
    local row = math.floor(start_row + (target_row - start_row) * ease_in_cubic(t))
    pcall(vim.api.nvim_win_set_config, win_id, { relative = relative, row = row, col = col })
  end, function()
    if callback then
      callback()
    end
  end)
end

return M
