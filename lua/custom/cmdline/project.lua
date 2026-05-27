-- nvim-cmdline/project.lua
-- Detects project context to provide dynamic theming.

local M = {}

---@class ProjectContext
---@field type  string  "go"|"rust"|"node"|"python"|"vim"|"generic"
---@field color string  hex color associated with the project type

local ACCENT_COLORS = require("custom.project_colors")

-- Project detection
local PROJECT_TYPES = {
  { file = "go.mod", type = "go", color = ACCENT_COLORS.go },
  { file = "Cargo.toml", type = "rust", color = ACCENT_COLORS.rust },
  { file = "package.json", type = "node", color = ACCENT_COLORS.javascript },
  { file = "requirements.txt", type = "python", color = ACCENT_COLORS.python },
  { file = "pyproject.toml", type = "python", color = ACCENT_COLORS.python },
  { file = "init.lua", type = "lua", color = ACCENT_COLORS.lua },
  { file = ".git", type = "generic", color = ACCENT_COLORS.generic },
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
