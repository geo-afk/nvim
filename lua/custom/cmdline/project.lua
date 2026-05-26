-- nvim-cmdline/project.lua
-- Detects project context to provide dynamic theming.

local M = {}

---@class ProjectContext
---@field type  string  "go"|"rust"|"node"|"python"|"vim"|"generic"
---@field color string  hex color associated with the project type

local PROJECT_TYPES = {
  { file = "go.mod", type = "go", color = "#00ADD8" },
  { file = "Cargo.toml", type = "rust", color = "#CE412B" },
  { file = "package.json", type = "node", color = "#8CC84B" },
  { file = "requirements.txt", type = "python", color = "#3776AB" },
  { file = "pyproject.toml", type = "python", color = "#3776AB" },
  { file = "init.lua", type = "vim", color = "#519ABA" },
  { file = ".git", type = "generic", color = "#F05032" },
}

local cache = {
  cwd = nil,
  context = nil,
}

---Detect the project type based on the current working directory.
---@return ProjectContext
function M.detect()
  local cwd = vim.fn.getcwd()
  if cache.cwd == cwd and cache.context then
    return cache.context
  end

  local context = { type = "generic", color = "#58a6ff" }

  for _, pt in ipairs(PROJECT_TYPES) do
    if vim.fn.filereadable(cwd .. "/" .. pt.file) == 1 or vim.fn.isdirectory(cwd .. "/" .. pt.file) == 1 then
      context.type = pt.type
      context.color = pt.color
      break
    end
  end

  cache.cwd = cwd
  cache.context = context
  return context
end

---Invalidate the detection cache.
function M.invalidate()
  cache.cwd = nil
  cache.context = nil
end

return M
