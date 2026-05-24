-- tabline/highlights.lua
-- Programmatically extracts colors from the active theme and generates
-- dynamic, cached project-specific highlight groups.

local M = {}

---@type table<string, table> Cached definitions for highlights
local dynamic_hl_cache = {}

-- Utility to convert integer color to hex string
local function int_to_hex(num)
  if not num then
    return nil
  end
  return string.format("#%06x", num)
end

-- Utility to darken a hex color (works for both dark and light modes)
local function darken_color(hex, factor)
  if not hex then
    return nil
  end
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  r = math.max(0, math.min(255, math.floor(r * factor)))
  g = math.max(0, math.min(255, math.floor(g * factor)))
  b = math.max(0, math.min(255, math.floor(b * factor)))
  return string.format("#%02x%02x%02x", r, g, b)
end

--- Get safe details from a highlight group
local function get_hl(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

--- Set or reapply all primary highlight groups.
--- Called on setup and on ColorScheme change.
function M.setup()
  -- Extract colors from colorscheme
  local normal = get_hl("Normal")
  local tabline = get_hl("TabLine")
  local tabline_sel = get_hl("TabLineSel")

  local normal_bg = int_to_hex(normal.bg) or "#1e1e2e"
  local normal_fg = int_to_hex(normal.fg) or "#cdd6f4"
  local tabline_fg = int_to_hex(tabline.fg) or "#a6adc8"

  -- Calculate the darker background for tabline fill
  local factor = vim.o.background == "dark" and 0.86 or 0.93
  local dark_bg = darken_color(normal_bg, factor) or "#11111b"

  -- Set core highlight groups
  vim.api.nvim_set_hl(0, "TabLineFill", { bg = dark_bg })
  vim.api.nvim_set_hl(0, "TabLine", { bg = dark_bg, fg = tabline_fg })
  vim.api.nvim_set_hl(0, "TabLineSel", { bg = normal_bg, fg = normal_fg, bold = true })
  vim.api.nvim_set_hl(0, "TabLineSep", { bg = dark_bg, fg = darken_color(tabline_fg, 0.6) or "#585b70" })
  vim.api.nvim_set_hl(0, "TabLineTrunc", { bg = dark_bg, fg = tabline_fg })

  -- Close button highlights
  vim.api.nvim_set_hl(0, "TabLineClose", { bg = dark_bg, fg = darken_color(tabline_fg, 0.7) or "#6c7086" })
  vim.api.nvim_set_hl(0, "TabLineCloseSel", { bg = normal_bg, fg = "#f38ba8", bold = true })

  -- Custom locks/readonly highlights
  vim.api.nvim_set_hl(0, "TabLineReadOnly", { bg = dark_bg, fg = "#f9e2af" })
  vim.api.nvim_set_hl(0, "TabLineReadOnlySel", { bg = normal_bg, fg = "#f9e2af" })

  -- Reset dynamic highlight cache so they are regenerated under the new colorscheme
  dynamic_hl_cache = {}
end

--- Dynamically construct a cached active highlight group with the project accent as the background.
---@param project_color string Hex color of the project accent
---@return string sel_hl, string edge_hl, string close_hl, string ro_hl
function M.get_project_highlights(project_color)
  local key = project_color:gsub("#", "")
  local sel_hl = "TabLineSelProj_" .. key
  local edge_hl = "TabLineProjEdgeSel_" .. key
  local close_hl = "TabLineProjCloseSel_" .. key
  local ro_hl = "TabLineProjRoSel_" .. key

  if dynamic_hl_cache[key] then
    return sel_hl, edge_hl, close_hl, ro_hl
  end

  local normal = get_hl("Normal")
  local normal_bg = int_to_hex(normal.bg) or "#1e1e2e"

  local factor = vim.o.background == "dark" and 0.86 or 0.93
  local dark_bg = darken_color(normal_bg, factor) or "#11111b"

  -- 1. Active container body with solid project color as background, high-contrast dark text
  vim.api.nvim_set_hl(0, sel_hl, {
    bg = project_color,
    fg = "#11111b",
    bold = true,
  })

  -- 2. Left/right edge slants (rendered as solid slants of project_color on top of dark_bg)
  vim.api.nvim_set_hl(0, edge_hl, {
    bg = dark_bg,
    fg = project_color,
  })

  -- 3. Close button inside the active project tab
  vim.api.nvim_set_hl(0, close_hl, {
    bg = project_color,
    fg = "#11111b",
    bold = true,
  })

  -- 4. Readonly lock icon inside the active project tab
  vim.api.nvim_set_hl(0, ro_hl, {
    bg = project_color,
    fg = "#11111b",
    bold = true,
  })

  dynamic_hl_cache[key] = true
  return sel_hl, edge_hl, close_hl, ro_hl
end

return M
