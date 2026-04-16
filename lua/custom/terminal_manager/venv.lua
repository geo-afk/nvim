--------------------------------------------------------------------------------
-- custom/terminal_manager/venv.lua
-- Detect virtual environments / language runtimes near a given directory.
-- Supports: Python venv, conda, pipenv, poetry, Node (nvm/.nvmrc),
--           Ruby (rbenv/rvm/bundler), Go modules, Rust (cargo).
--
-- Returns a venv_info table:
--   { type, name, path, activate_cmd, env }
-- or nil when nothing is found.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local M = {}

-- ── Filesystem helpers ────────────────────────────────────────────────────────

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*l")
  f:close()
  return s and vim.trim(s) or nil
end

local function is_dir(path)
  local s = vim.uv.fs_stat(path)
  return s and s.type == "directory"
end

--- Walk up from `start_dir` looking for a file/dir matching `name`.
--- Returns the containing directory, or nil.
local function find_upward(start_dir, name)
  local dir = start_dir
  for _ = 1, 10 do -- limit depth to 10 levels
    if exists(dir .. "/" .. name) then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

-- ── Detectors ─────────────────────────────────────────────────────────────────

--- Python: .venv/, venv/, env/, .env/ with a pyvenv.cfg, or conda env.
local function detect_python(dir)
  local venv_names = { ".venv", "venv", "env", ".env", "__pypackages__" }
  for _, name in ipairs(venv_names) do
    local venv_path = dir .. "/" .. name
    if is_dir(venv_path) and exists(venv_path .. "/pyvenv.cfg") then
      local bin = venv_path .. "/bin"
      if not is_dir(bin) then
        bin = venv_path .. "/Scripts"
      end -- Windows
      return {
        type = "python",
        name = name,
        path = venv_path,
        activate_cmd = "source " .. bin .. "/activate",
        env = {
          VIRTUAL_ENV = venv_path,
          PATH = bin .. ":" .. (os.getenv("PATH") or ""),
          VIRTUAL_ENV_PROMPT = "(" .. name .. ")",
        },
        display = "🐍 " .. name,
      }
    end
  end

  -- poetry: check pyproject.toml with [tool.poetry] section
  local pyproject = dir .. "/pyproject.toml"
  if exists(pyproject) then
    local out = vim.fn.systemlist("poetry env info --path 2>/dev/null")
    if out and #out > 0 and out[1] ~= "" and not out[1]:match("^Error") then
      local venv_path = vim.trim(out[1])
      local bin = venv_path .. "/bin"
      return {
        type = "python_poetry",
        name = "poetry",
        path = venv_path,
        activate_cmd = "source " .. bin .. "/activate",
        env = {
          VIRTUAL_ENV = venv_path,
          PATH = bin .. ":" .. (os.getenv("PATH") or ""),
        },
        display = "🐍 poetry",
      }
    end
  end

  -- pipenv
  if exists(dir .. "/Pipfile") then
    local out = vim.fn.systemlist("pipenv --venv 2>/dev/null")
    if out and #out > 0 and out[1] ~= "" and not out[1]:match("^Error") then
      local venv_path = vim.trim(out[1])
      local bin = venv_path .. "/bin"
      return {
        type = "python_pipenv",
        name = "pipenv",
        path = venv_path,
        activate_cmd = "source " .. bin .. "/activate",
        env = {
          VIRTUAL_ENV = venv_path,
          PATH = bin .. ":" .. (os.getenv("PATH") or ""),
        },
        display = "🐍 pipenv",
      }
    end
  end

  -- conda: CONDA_DEFAULT_ENV in environment
  local conda_env = os.getenv("CONDA_DEFAULT_ENV")
  if conda_env and conda_env ~= "" and conda_env ~= "base" then
    return {
      type = "conda",
      name = conda_env,
      path = os.getenv("CONDA_PREFIX") or "",
      display = "🐍 conda:" .. conda_env,
    }
  end

  return nil
end

--- Node.js: .nvmrc, .node-version, or node_modules/.bin present.
local function detect_node(dir)
  -- .nvmrc
  local nvmrc = dir .. "/.nvmrc"
  if exists(nvmrc) then
    local version = read_file(nvmrc) or "lts"
    return {
      type = "node_nvm",
      name = "node@" .. version,
      path = dir,
      display = "⬡ node@" .. version,
      note = "Run 'nvm use' to activate",
    }
  end

  -- .node-version (volta / nodenv)
  local nv = dir .. "/.node-version"
  if exists(nv) then
    local version = read_file(nv) or "?"
    return {
      type = "node_volta",
      name = "node@" .. version,
      path = dir,
      display = "⬡ node@" .. version,
    }
  end

  -- package.json with engines.node
  local pkg = dir .. "/package.json"
  if exists(pkg) then
    local bin = dir .. "/node_modules/.bin"
    if is_dir(bin) then
      return {
        type = "node",
        name = "node",
        path = dir,
        env = { PATH = bin .. ":" .. (os.getenv("PATH") or "") },
        display = "⬡ node (local)",
      }
    end
    return {
      type = "node",
      name = "node",
      path = dir,
      display = "⬡ node",
    }
  end

  return nil
end

--- Ruby: .ruby-version, Gemfile, or rbenv/rvm indicators.
local function detect_ruby(dir)
  local rv = dir .. "/.ruby-version"
  if exists(rv) then
    local version = read_file(rv) or "?"
    return {
      type = "ruby",
      name = "ruby@" .. version,
      path = dir,
      display = "💎 ruby@" .. version,
    }
  end
  if exists(dir .. "/Gemfile") then
    return {
      type = "ruby_bundler",
      name = "bundler",
      path = dir,
      display = "💎 bundler",
    }
  end
  return nil
end

--- Go: go.mod present.
local function detect_go(dir)
  if exists(dir .. "/go.mod") then
    return {
      type = "go",
      name = "go",
      path = dir,
      display = "🐹 go module",
    }
  end
  return nil
end

--- Rust: Cargo.toml present.
local function detect_rust(dir)
  if exists(dir .. "/Cargo.toml") then
    return {
      type = "rust",
      name = "cargo",
      path = dir,
      display = "🦀 cargo",
    }
  end
  return nil
end

-- ── Public ────────────────────────────────────────────────────────────────────

--- Detect a virtual environment / runtime for `dir`.
--- Results are cached per directory.
---@param dir string  Absolute path to check (usually cwd of a terminal).
---@return table|nil  venv_info or nil
function M.detect(dir)
  if not dir or dir == "" then
    return nil
  end

  if state.venv_cache[dir] ~= nil then
    return state.venv_cache[dir] or nil
  end

  -- Try each detector in priority order.
  local result = detect_python(dir) or detect_node(dir) or detect_ruby(dir) or detect_go(dir) or detect_rust(dir)

  -- If nothing found in `dir`, walk up and try parent directories.
  if not result then
    local parent = find_upward(vim.fn.fnamemodify(dir, ":h"), "go.mod")
      or find_upward(vim.fn.fnamemodify(dir, ":h"), "Cargo.toml")
      or find_upward(vim.fn.fnamemodify(dir, ":h"), "package.json")
    if parent and parent ~= dir then
      result = detect_node(parent) or detect_go(parent) or detect_rust(parent)
    end
  end

  -- Cache (false = explicitly "nothing found" so we don't re-probe).
  state.venv_cache[dir] = result or false
  return result
end

--- Invalidate the cache for a specific dir (or all if dir=nil).
function M.invalidate(dir)
  if dir then
    state.venv_cache[dir] = nil
  else
    state.venv_cache = {}
  end
end

--- Return a short display string for the given terminal's venv, or nil.
function M.display_for(t)
  if not t then
    return nil
  end
  local venv = t.venv
  if not venv then
    return nil
  end
  return venv.display
end

--- Merge venv.env into the profile env table (non-destructively).
function M.apply_env(venv, base_env)
  if not venv or not venv.env then
    return base_env
  end
  local out = vim.tbl_extend("force", base_env or {}, venv.env)
  return out
end

return M
