-- nvim-cmdline/debounce.lua
-- Reusable debounce utility via libuv timers.

local M = {}

local uv = vim.uv or vim.loop

-- Neovim uses LuaJIT where table.unpack is the standard.
-- Plain `unpack` is also available as a global in LuaJIT for compatibility,
-- but prefer table.unpack to be explicit and forward-compatible.
local _unpack = table.unpack or unpack

---Create a debounced wrapper around `fn`.
---Repeated calls reset the delay.  The wrapped function receives the same
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

    -- Cancel any existing pending call
    if timer then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      timer = nil
    end

    timer = uv.new_timer()
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        if timer and not timer:is_closing() then
          timer:close()
        end
        timer = nil
        fn(_unpack(args))
      end)
    )
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
