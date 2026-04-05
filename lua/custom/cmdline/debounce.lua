-- nvim-cmdline/debounce.lua
-- Reusable debounce utility via libuv timers.
--
-- Optimisation: the internal timer is created once on the first call and then
-- re-used (stop + start) on every subsequent call within the debounce window.
-- The previous implementation closed and re-created the timer on every call,
-- which is significantly more expensive.

local M = {}

local uv = vim.uv or vim.loop

local _unpack = table.unpack or unpack

---Create a debounced wrapper around `fn`.
---Repeated calls reset the delay. The wrapped function receives the same
---arguments that were passed on the last call before the timer fires.
---@param fn  fun(...)   the function to debounce
---@param ms  integer    delay in milliseconds (must be > 0)
---@return fun(...)      debounced function
---@return fun()         cancel function – stops a pending call without firing it
function M.new(fn, ms)
  assert(type(fn) == "function", "debounce.new: fn must be a function")
  assert(type(ms) == "number" and ms > 0, "debounce.new: ms must be a positive number")

  local timer = nil ---@type uv_timer_t|nil

  local function debounced(...)
    local args = { ... }

    if timer then
      -- Reuse the existing timer: stop the pending call and restart the delay.
      -- This avoids the close+GC+create overhead of the previous approach.
      timer:stop()
      timer:start(
        ms,
        0,
        vim.schedule_wrap(function()
          fn(_unpack(args))
        end)
      )
    else
      timer = uv.new_timer()
      timer:start(
        ms,
        0,
        vim.schedule_wrap(function()
          fn(_unpack(args))
        end)
      )
    end
  end

  local function cancel()
    if timer then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      timer = nil
    end
  end

  return debounced, cancel
end

return M
