--------------------------------------------------------------------------------
-- custom/terminal_manager/env.lua
-- Project-local .nvim_env parsing and terminal env injection.
--------------------------------------------------------------------------------

local M = {}

local ENV_FILE = ".nvim_env"

local function project_root()
  return vim.uv.cwd() or vim.fn.getcwd()
end

local function env_file_path(root)
  return vim.fs.joinpath(root, ENV_FILE)
end

local function read_env_lines(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end
  return vim.fn.readfile(path)
end

function M.parse(root)
  local lines = read_env_lines(env_file_path(root or project_root()))
  local env = {}

  if not lines then
    return env
  end

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      local key, value = trimmed:match("^([%w_]+)=(.*)$")
      if key then
        env[key] = value
      end
    end
  end

  return env
end

function M.apply(base_env, root)
  return vim.tbl_extend("force", base_env or {}, M.parse(root))
end

function M.add_env_var()
  local root = project_root()
  local path = env_file_path(root)

  vim.ui.input({ prompt = "Env key: ", zindex = 160 }, function(key)
    if key == nil then
      return
    end

    key = vim.trim(key)
    if key == "" then
      vim.notify("TermManager: environment key cannot be empty", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = ("Env value for %s: "):format(key), zindex = 160 }, function(value)
      if value == nil then
        return
      end

      vim.fn.writefile({ ("%s=%s"):format(key, value) }, path, "a")
      vim.notify(("TermManager: saved %s to %s"):format(key, ENV_FILE), vim.log.levels.INFO)
    end)
  end)
end

return M
