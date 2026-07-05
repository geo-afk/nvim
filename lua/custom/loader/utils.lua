-- lua/custom/loader/utils.lua
-- Pure utility functions with zero side effects.
-- No circular dependencies: this file requires nothing from the loader.

local M = {}

-- ── Platform ─────────────────────────────────────────────────────────────────

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
M.path_sep = M.is_windows and "\\" or "/"

-- ── Time ─────────────────────────────────────────────────────────────────────

-- Monotonic nanosecond clock (LuaJIT / libuv).
function M.hrtime()
  return vim.uv.hrtime()
end

function M.ns_to_ms(ns)
  return ns * 1e-6
end

-- ── Logging ───────────────────────────────────────────────────────────────────

-- Deferred access to state to avoid import cycle at module init time.
local function cfg()
  return require("custom.loader.state").config
end

---@param level "debug"|"info"|"warn"|"error"
function M.log(level, fmt, ...)
  if level == "debug" and not cfg().debug then
    return
  end
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  local prefix = ("[loader/%s] "):format(level:upper())
  local nvim_level = ({
    debug = vim.log.levels.DEBUG,
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
  })[level] or vim.log.levels.INFO
  vim.notify(prefix .. msg, nvim_level, { title = "custom.loader" })
end

-- ── Safe require ──────────────────────────────────────────────────────────────

--- Attempt require, returning (true, module) or (false, err_string).
--- Does not log: the caller (core.do_require) logs once, with timing attached.
function M.safe_require(mod)
  local ok, result = pcall(require, mod)
  if not ok then
    return false, tostring(result)
  end
  return true, result
end

-- ── Table helpers ─────────────────────────────────────────────────────────────

function M.shallow_copy(t)
  local c = {}
  for k, v in pairs(t) do
    c[k] = v
  end
  return c
end

-- Normalise a nil / string / table value to a list (always returns a table).
function M.to_list(v)
  if v == nil then
    return {}
  end
  if type(v) == "string" then
    return { v }
  end
  if type(v) == "table" then
    return v
  end
  return { v }
end

-- Returns true when `list` contains `item`.
function M.list_contains(list, item)
  for _, v in ipairs(list) do
    if v == item then
      return true
    end
  end
  return false
end

-- ── String helpers ────────────────────────────────────────────────────────────

-- Neovim display-friendly module path ("a.b.c" → "a/b/c").
function M.mod_to_path(mod)
  return mod:gsub("%.", M.path_sep)
end

-- Truncate a string to max_len, appending "…" when trimmed.
function M.trunc(s, max_len)
  if #s <= max_len then
    return s
  end
  return s:sub(1, max_len - 1) .. "…"
end

return M
