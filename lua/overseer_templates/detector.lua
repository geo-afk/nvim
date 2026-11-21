-- =============================================================================
-- lua/overseer_templates/detector.lua
-- Centralized project and language runtime detection for Overseer task runners.
-- Ensures runner options only appear when inside a project for that runner/language.
-- =============================================================================

local M = {}

local home_dir = vim.fs.normalize(vim.fn.expand("~"))

---Resolve effective directory to search (from opts, active buffer, or cwd)
---@param opts? overseer.SearchParams
---@return string
function M.get_dir(opts)
  if opts and opts.dir and opts.dir ~= "" then
    return vim.fs.normalize(opts.dir)
  end
  local buf = vim.api.nvim_buf_get_name(0)
  if buf ~= "" and vim.bo.buftype == "" then
    return vim.fs.normalize(vim.fn.fnamemodify(buf, ":p:h"))
  end
  return vim.fs.normalize(vim.fn.getcwd())
end

---Resolve effective filetype
---@param opts? overseer.SearchParams
---@return string
function M.get_filetype(opts)
  if opts and opts.filetype and opts.filetype ~= "" then
    return opts.filetype
  end
  return vim.bo.filetype or ""
end

---Search upwards from start_dir for project root markers without escaping beyond repo or home dir
---@param start_dir string
---@param markers string[]
---@return string|nil
function M.find_root(start_dir, markers)
  if not start_dir or start_dir == "" then
    start_dir = vim.fn.getcwd()
  end
  start_dir = vim.fs.normalize(start_dir)

  -- Stop searching upwards once we hit the git root or user home directory
  local git_root = vim.fs.root(start_dir, { ".git" })
  local stop_dir = git_root or home_dir

  local found = vim.fs.find(markers, {
    upward = true,
    path = start_dir,
    stop = vim.fs.dirname(stop_dir),
    type = "file",
    limit = 1,
  })

  if #found > 0 then
    local root = vim.fs.normalize(vim.fs.dirname(found[1]))
    -- If marker was only found in user's root home dir (~), do not treat home as project root
    if root == home_dir and start_dir ~= home_dir then
      return nil
    end
    return root
  end

  return nil
end

-- ── 1. Go Project Detection ──────────────────────────────────────────────────
function M.is_go(opts)
  if vim.fn.executable("go") == 0 then
    return false, nil
  end
  local dir = M.get_dir(opts)
  local ft = M.get_filetype(opts)
  local root = M.find_root(dir, { "go.mod", "go.work" })
  if root then
    return true, root
  end
  if ft == "go" or ft == "gomod" or ft == "gowork" then
    return true, dir
  end
  local buf = vim.api.nvim_buf_get_name(0)
  if buf:match("%.go$") then
    return true, dir
  end
  return false, nil
end

-- ── 2. Python Project Detection ──────────────────────────────────────────────
local PYTHON_MARKERS = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "poetry.lock",
  "manage.py",
  ".python-version",
  "tox.ini",
  "pytest.ini",
}

function M.is_python(opts)
  local dir = M.get_dir(opts)
  local ft = M.get_filetype(opts)
  local root = M.find_root(dir, PYTHON_MARKERS)
  if root then
    return true, root
  end
  if ft == "python" then
    return true, dir
  end
  local buf = vim.api.nvim_buf_get_name(0)
  if buf:match("%.py$") then
    return true, dir
  end
  return false, nil
end

---Find the preferred python executable: virtualenv if present, otherwise system python
---@param root? string
---@return string
function M.get_python_bin(root)
  root = root or vim.fn.getcwd()
  local candidates = {
    root .. "/.venv/Scripts/python.exe",
    root .. "/venv/Scripts/python.exe",
    root .. "/env/Scripts/python.exe",
    root .. "/.venv/bin/python",
    root .. "/venv/bin/python",
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      return path
    end
  end
  if vim.fn.executable("python") == 1 then
    return "python"
  elseif vim.fn.executable("python3") == 1 then
    return "python3"
  elseif vim.fn.executable("py") == 1 then
    return "py"
  end
  return "python"
end

-- ── 3. Angular Project Detection ─────────────────────────────────────────────
function M.is_angular(opts)
  local dir = M.get_dir(opts)
  local root = M.find_root(dir, { "angular.json" })
  if root and (vim.fn.executable("ng") == 1 or vim.fn.executable("npx") == 1) then
    return true, root
  end
  return false, nil
end

-- ── 4. Node / TypeScript Detection ───────────────────────────────────────────
function M.is_node(opts)
  local dir = M.get_dir(opts)
  local ft = M.get_filetype(opts)
  local root = M.find_root(dir, { "package.json" })
  if root then
    return true, root
  end
  if ft == "javascript" or ft == "typescript" or ft == "javascriptreact" or ft == "typescriptreact" then
    return true, dir
  end
  return false, nil
end

-- ── 5. C / C++ Detection ─────────────────────────────────────────────────────
function M.is_cpp(opts)
  local dir = M.get_dir(opts)
  local ft = M.get_filetype(opts)
  local root = M.find_root(dir, { "CMakeLists.txt", "compile_commands.json" })
  if root then
    return true, root
  end
  if ft == "c" or ft == "cpp" then
    return true, dir
  end
  local buf = vim.api.nvim_buf_get_name(0)
  if buf:match("%.c$") or buf:match("%.cpp$") or buf:match("%.cc$") or buf:match("%.h$") or buf:match("%.hpp$") then
    return true, dir
  end
  local make_root = M.find_root(dir, { "Makefile", "makefile", "GNUmakefile" })
  if make_root then
    local c_files = vim.fs.find(function(name)
      return name:match("%.c$") or name:match("%.cpp$") or name:match("%.cc$") or name:match("%.h$")
    end, { path = make_root, limit = 1, type = "file" })
    if #c_files > 0 then
      return true, make_root
    end
  end
  return false, nil
end

return M
