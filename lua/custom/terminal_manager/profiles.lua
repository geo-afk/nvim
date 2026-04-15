--------------------------------------------------------------------------------
-- terminal_manager/profiles.lua
-- All profile-related helpers: lookup, validation, command/env building.
--------------------------------------------------------------------------------

local utils = require("custom.terminal_manager.utils")

local M = {}

--- Lazy accessor so we never hold a stale reference to the config table.
local function cfg()
  return require("custom.terminal_manager").config
end

-- ── Lookup helpers ────────────────────────────────────────────────────────────

--- Find a profile by name, or nil.
function M.find_profile(name)
  if not name or name == "" then
    return nil
  end
  for _, profile in ipairs(cfg().profiles) do
    if profile.name == name then
      return profile
    end
  end
  return nil
end

--- The configured default profile (falls back to profiles[1]).
function M.default_profile()
  return M.find_profile(cfg().default_profile) or cfg().profiles[1]
end

--- The configured automation profile (falls back to default_profile).
function M.automation_profile()
  return M.find_profile(cfg().automation_profile) or M.default_profile()
end

-- ── Shell helpers ─────────────────────────────────────────────────────────────

--- Return the display-safe string for a shell value (string or table).
function M.shell_cmd_display(shell)
  if type(shell) == "table" then
    return tostring(shell[1] or "")
  end
  return tostring(shell or "")
end

--- True when the given shell executable can be found on the system.
function M.shell_is_executable(shell)
  if type(shell) == "table" then
    shell = shell[1]
  end
  if not shell or shell == "" then
    return false
  end
  -- Absolute or relative path → check file existence.
  if shell:match("[/\\]") then
    return vim.uv.fs_stat(shell) ~= nil
  end
  -- Plain name → use PATH lookup.
  return vim.fn.executable(shell) == 1
end

--- Emit a warning for every profile whose shell cannot be found.
--- Called once at startup (via vim.schedule so Neovim is fully initialised).
function M.validate_profiles()
  for _, profile in ipairs(cfg().profiles) do
    local shell = profile.shell or utils.get_shell()
    if M.shell_cmd_display(shell) ~= "" and not M.shell_is_executable(shell) then
      vim.schedule(function()
        vim.notify(
          ("TermManager: profile '%s' shell not found: %s"):format(profile.name, M.shell_cmd_display(shell)),
          vim.log.levels.WARN
        )
      end)
    end
  end
end

-- ── Command / environment builders ────────────────────────────────────────────

--- Build the shell command list/string to pass to termopen().
function M.profile_cmd(profile)
  profile = profile or {}
  local shell = profile.shell or utils.get_shell()
  -- Already a table (e.g. { "/usr/bin/env", "bash" }) – use as-is.
  if type(shell) == "table" then
    return shell
  end
  if profile.args and #profile.args > 0 then
    local cmd = { shell }
    vim.list_extend(cmd, profile.args)
    return cmd
  end
  return shell
end

--- Build the environment table for termopen().
--- Merges profile.env on top of the inherited process environment (when
--- config.inherit_env is true).  Setting a key to false removes it.
function M.profile_env(profile)
  local extra = (profile or {}).env or {}
  if not cfg().inherit_env then
    local out = {}
    for key, value in pairs(extra) do
      if value ~= false and value ~= vim.NIL then
        out[key] = tostring(value)
      end
    end
    return out
  end

  local out = vim.fn.environ()
  for key, value in pairs(extra) do
    if value == false or value == vim.NIL then
      out[key] = nil
    else
      out[key] = tostring(value)
    end
  end
  return out
end

return M
