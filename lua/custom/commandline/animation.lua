local Animation = {}
local M = {} -- This will be the module's config reference, passed from init

local function setup_animation(config)
  M.config = config
end

-- Fallback simple animations using vim.uv timers (modern best practice)
Animation.timers = {}
Animation.timer_id = 0
function Animation:create_timer()
  local timer = vim.uv.new_timer()
  if timer then
    self.timer_id = self.timer_id + 1
    self.timers[self.timer_id] = timer
    return timer, self.timer_id
  end
  return nil, nil
end

function Animation:stop_timer(id)
  local timer = self.timers[id]
  if timer and not timer:is_closing() then
    pcall(function()
      timer:stop()
      timer:close()
    end)
  end
  self.timers[id] = nil
end

function Animation:fade_in(win, callback)
  if not M.config.animation.enabled or not win or not vim.api.nvim_win_is_valid(win) then
    if callback then
      callback()
    end
    return
  end
  local Utils = require('custom.commandline.utils')
  local timer, id = self:create_timer()
  if not timer then
    if callback then
      callback()
    end
    return
  end
  local steps = 10
  local step_time = M.config.animation.duration / steps
  local current_step = 0
  timer:start(
    0,
    step_time,
    vim.schedule_wrap(function()
      current_step = current_step + 1
      local progress = current_step / steps
      local eased = Utils.ease_out_cubic(progress)
      local blend = math.floor((1 - eased) * 100)
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_set_option, win, "winblend", blend)
      end
      if current_step >= steps then
        self:stop_timer(id)
        if callback then
          callback()
        end
      end
    end)
  )
end

function Animation:slide_in(win, direction, callback)
  if not M.config.animation.enabled or not win or not vim.api.nvim_win_is_valid(win) then
    if callback then
      callback()
    end
    return
  end
  local Utils = require('custom.commandline.utils')
  local timer, id = self:create_timer()
  if not timer then
    if callback then
      callback()
    end
    return
  end
  local config = vim.api.nvim_win_get_config(win)
  local target_row = config.row
  local start_row = target_row
      + (direction == "down" and -M.config.animation.slide_distance or M.config.animation.slide_distance)
  local steps = 10
  local step_time = M.config.animation.duration / steps
  local current_step = 0
  timer:start(
    0,
    step_time,
    vim.schedule_wrap(function()
      current_step = current_step + 1
      local progress = current_step / steps
      local eased = Utils.ease_out_cubic(progress)
      local current_row = start_row + (target_row - start_row) * eased
      if vim.api.nvim_win_is_valid(win) then
        config.row = math.floor(current_row)
        pcall(vim.api.nvim_win_set_config, win, config)
      end
      if current_step >= steps then
        self:stop_timer(id)
        if callback then
          callback()
        end
      end
    end)
  )
end

function Animation:pulse(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local timer, id = self:create_timer()
  if not timer then
    return
  end
  local original_border = vim.api.nvim_win_get_option(win, "winhighlight")
  pcall(
    vim.api.nvim_win_set_option,
    win,
    "winhighlight",
    original_border .. ",FloatBorder:CmdlineAccent",
    win
  )
  timer:start(
    300,
    0,
    vim.schedule_wrap(function()
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_set_option, win, "winhighlight", original_border)
      end
      self:stop_timer(id)
    end)
  )
end

function Animation:cleanup()
  for id, timer in pairs(self.timers) do
    if timer and not timer:is_closing() then
      pcall(function()
        timer:stop()
        timer:close()
      end)
    end
  end
  self.timers = {}
end

-- Debounce helper using vim.uv (modern, reliable)
local function debounce(fn, delay)
  local timer_id = nil
  return function(...)
    local args = { ... }
    if timer_id and Animation.timers[timer_id] then
      Animation:stop_timer(timer_id)
    end
    local timer, id = Animation:create_timer()
    if timer then
      timer_id = id
      timer:start(
        delay,
        0,
        vim.schedule_wrap(function()
          timer_id = nil
          fn(unpack(args))
          Animation:stop_timer(id)
        end)
      )
    end
  end
end

return { Animation = Animation, debounce = debounce, setup = setup_animation }
