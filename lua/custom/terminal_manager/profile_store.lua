--------------------------------------------------------------------------------
-- custom.terminal_manager/profile_store.lua
-- Persist user-created profiles to a JSON file in stdpath("data").
--
-- Storage path:  {stdpath("data")}/custom.terminal_manager/profiles.json
--
-- On startup: persisted profiles are merged with config.profiles.
-- On save:    all profiles (config + user-created) are written to disk.
--------------------------------------------------------------------------------

local M = {}

local store_dir = vim.fn.stdpath("data") .. "/custom.terminal_manager"
local store_path = store_dir .. "/profiles.json"

-- ── JSON helpers (Neovim 0.10+ ships vim.json) ────────────────────────────────

local function encode(t)
  return vim.json.encode(t)
end

local function decode(s)
  return vim.json.decode(s)
end

-- ── File I/O ──────────────────────────────────────────────────────────────────

--- Ensure the storage directory exists.
local function ensure_dir()
  if vim.fn.isdirectory(store_dir) == 0 then
    vim.fn.mkdir(store_dir, "p")
  end
end

--- Read raw JSON string from disk.  Returns nil on any error.
local function read_raw()
  local f = io.open(store_path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

--- Write raw JSON string to disk.  Returns true on success.
local function write_raw(s)
  ensure_dir()
  local f = io.open(store_path, "w")
  if not f then
    return false
  end
  f:write(s)
  f:close()
  return true
end

-- ── Public API ─────────────────────────────────────────────────────────────────

--- Load persisted profiles from disk.
--- Returns a list (possibly empty) of profile tables.
function M.load()
  local raw = read_raw()
  if not raw or raw == "" then
    return {}
  end
  local ok, data = pcall(decode, raw)
  if not ok or type(data) ~= "table" then
    vim.notify("TermManager: could not parse profiles file – starting fresh.\n" .. store_path, vim.log.levels.WARN)
    return {}
  end
  -- data is expected to be a list of profile tables.
  if not vim.islist(data) then
    return {}
  end
  return data
end

--- Save a list of profile tables to disk.
---@param profiles table[]
---@return boolean success
function M.save(profiles)
  local ok, s = pcall(encode, profiles)
  if not ok then
    vim.notify("TermManager: failed to encode profiles: " .. s, vim.log.levels.ERROR)
    return false
  end
  if not write_raw(s) then
    vim.notify("TermManager: could not write profiles to " .. store_path, vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Merge persisted profiles into config.profiles.
--- Profiles already present in config (by name) are NOT overwritten –
--- the in-code definition wins.  Only persisted-only profiles are appended.
function M.merge_into_config()
  local cfg = require("custom.terminal_manager").config
  local persisted = M.load()
  if #persisted == 0 then
    return
  end

  -- Build a set of names already in config.
  local known = {}
  for _, p in ipairs(cfg.profiles) do
    known[p.name] = true
  end

  local added = 0
  for _, p in ipairs(persisted) do
    if not known[p.name] then
      table.insert(cfg.profiles, p)
      known[p.name] = true
      added = added + 1
    end
  end

  if added > 0 then
    -- Re-register keymaps for newly added profiles.
    require("custom.terminal_manager.profiles").register_profile_keymaps()
  end
end

--- Persist all current config.profiles to disk.
function M.save_all()
  local cfg = require("custom.terminal_manager").config
  M.save(cfg.profiles)
end

--- Return the storage file path (for display purposes).
function M.path()
  return store_path
end

return M
