-- tabline/projects.lua
-- Detects project root, directory name, language category, and accent color.
-- Performs caching to ensure O(1) hot-path performance inside the render loop.

local M = {}

local ACCENT_COLORS = require("custom.project_colors")

---@class ProjectInfo
---@field root  string   Absolute path to project root
---@field name  string   Base name of the project folder
---@field type  string   Category ("rust"|"go"|"python"|"web"|"generic"|"none")
---@field color string   Hex color code for accents

-- Curated harmonized accent colors
local COLOR_PALETTE = {
  rust = ACCENT_COLORS.rust,
  go = ACCENT_COLORS.go,
  python = ACCENT_COLORS.python,
  web = "#cba6f7",
  c_cpp = "#a6e3a1",
  generic = ACCENT_COLORS.generic,
  none = ACCENT_COLORS.none,
}
-- Caches resolved projects by bufnr
local project_cache = {}

--- Reset the cache (e.g. on rename or closing buffers)
function M.invalidate_cache(bufnr)
  if bufnr then
    project_cache[bufnr] = nil
  else
    project_cache = {}
  end
end

--- Detect project details for a buffer.
---@param bufnr integer
---@return ProjectInfo
function M.detect(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return { root = "", name = "", type = "none", color = COLOR_PALETTE.none }
  end

  local cached = project_cache[bufnr]
  if cached then
    return cached
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    local info = { root = "", name = "", type = "none", color = COLOR_PALETTE.none }
    project_cache[bufnr] = info
    return info
  end

  -- Detect project root using modern vim.fs.root
  local root = vim.fs.root(path, {
    ".git",
    "Cargo.toml",
    "go.mod",
    "package.json",
    "requirements.txt",
    "pyproject.toml",
    "Makefile",
  })

  if not root then
    local info = { root = "", name = "", type = "none", color = COLOR_PALETTE.none }
    project_cache[bufnr] = info
    return info
  end

  -- Identify project type based on contents of root
  local p_type = "generic"
  if vim.uv.fs_stat(root .. "/Cargo.toml") then
    p_type = "rust"
  elseif vim.uv.fs_stat(root .. "/go.mod") then
    p_type = "go"
  elseif vim.uv.fs_stat(root .. "/package.json") then
    p_type = "web"
  elseif vim.uv.fs_stat(root .. "/requirements.txt") or vim.uv.fs_stat(root .. "/pyproject.toml") then
    p_type = "python"
  elseif vim.uv.fs_stat(root .. "/Makefile") then
    p_type = "c_cpp"
  end

  local name = vim.fs.basename(root) or "Project"
  local color = COLOR_PALETTE[p_type] or COLOR_PALETTE.generic

  local info = {
    root = root,
    name = name,
    type = p_type,
    color = color,
  }

  project_cache[bufnr] = info
  return info
end

return M
