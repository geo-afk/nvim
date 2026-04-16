--------------------------------------------------------------------------------
-- terminal_manager/profiles.lua
-- Profile lookup, validation, cmd/env building, keymap registration.
--------------------------------------------------------------------------------

local utils = require("custom.terminal_manager.utils")

local M = {}

local function cfg()
  return require("custom.terminal_manager.config").values
end

-- ── Lookup ────────────────────────────────────────────────────────────────────

function M.find_profile(name)
  if not name or name == "" then
    return nil
  end
  for _, p in ipairs(cfg().profiles) do
    if p.name == name then
      return p
    end
  end
  return nil
end

function M.default_profile()
  return M.find_profile(cfg().default_profile) or cfg().profiles[1]
end

function M.automation_profile()
  return M.find_profile(cfg().automation_profile) or M.default_profile()
end

-- ── Shell helpers ─────────────────────────────────────────────────────────────

function M.shell_cmd_display(shell)
  if type(shell) == "table" then
    return tostring(shell[1] or "")
  end
  return tostring(shell or "")
end

function M.shell_is_executable(shell)
  if type(shell) == "table" then
    shell = shell[1]
  end
  if not shell or shell == "" then
    return false
  end
  if shell:match("[/\\]") then
    return vim.uv.fs_stat(shell) ~= nil
  end
  return vim.fn.executable(shell) == 1
end

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

-- ── Command / env builders ────────────────────────────────────────────────────

--- Build the termopen() command, honouring login_shell.
function M.profile_cmd(profile)
  profile = profile or {}
  local shell = profile.shell or utils.get_shell()
  if type(shell) == "table" then
    return shell
  end

  local args = vim.deepcopy(profile.args or {})

  -- login_shell: prepend -l when the shell supports it
  if profile.login_shell then
    local base = type(shell) == "table" and shell[1] or shell
    local name = vim.fn.fnamemodify(base, ":t")
    if name == "bash" or name == "zsh" or name == "fish" or name == "sh" or name == "ksh" or name == "dash" then
      table.insert(args, 1, "-l")
    end
  end

  if #args > 0 then
    local cmd = { shell }
    vim.list_extend(cmd, args)
    return cmd
  end
  return shell
end

function M.profile_env(profile)
  local extra = (profile or {}).env or {}
  if not cfg().inherit_env then
    local out = {}
    for k, v in pairs(extra) do
      if v ~= false and v ~= vim.NIL then
        out[k] = tostring(v)
      end
    end
    return out
  end
  local out = vim.fn.environ()
  for k, v in pairs(extra) do
    if v == false or v == vim.NIL then
      out[k] = nil
    else
      out[k] = tostring(v)
    end
  end
  return out
end

-- ── Profile keymaps ───────────────────────────────────────────────────────────
-- Each profile can define a `keymap` field (e.g. "<leader>zg").
-- We track which keymaps we registered so we can clean up on reload.
local registered_keymaps = {}

function M.register_profile_keymaps()
  -- Remove previously registered keymaps
  for _, km in ipairs(registered_keymaps) do
    pcall(vim.keymap.del, "n", km)
  end
  registered_keymaps = {}

  for _, profile in ipairs(cfg().profiles) do
    local km = profile.keymap
    if km and km ~= "" then
      local pname = profile.name
      vim.keymap.set("n", km, function()
        local tm = require("custom.terminal_manager")
        -- Find the first alive terminal using this profile.
        local state = require("custom.terminal_manager.state")
        for _, t in ipairs(state.terminals) do
          if (t.profile or {}).name == pname then
            if not require("custom.terminal_manager.utils").panel_open() then
              tm.open()
            end
            require("custom.terminal_manager.terminal").show(t)
            return
          end
        end
        -- None open → create one.
        tm.new_term(nil, pname)
      end, { desc = "terminal: open profile '" .. pname .. "'" })
      registered_keymaps[#registered_keymaps + 1] = km
    end
  end
end

--- Return a list of { keymap, profile_name } for display purposes.
function M.keymap_list()
  local out = {}
  for _, profile in ipairs(cfg().profiles) do
    if profile.keymap and profile.keymap ~= "" then
      out[#out + 1] = {
        keymap = profile.keymap,
        name = profile.name,
        icon = profile.icon or "$",
        color = profile.color,
      }
    end
  end
  return out
end

return M
