-- tabline/highlights.lua
-- Defines plugin-specific highlight groups, derived from built-in
-- TabLine / TabLineSel so they adapt automatically to any colorscheme.
-- Re-run setup() on ColorScheme events to stay in sync.

local M = {}

---@type table<string, table>  group_name -> nvim_set_hl opts
local groups = {
  -- Inactive close button
  TabLineClose       = { link = "TabLine"    , default = true },
  -- Active close button
  TabLineCloseSel    = { link = "TabLineSel" , default = true },
  -- Truncation arrows  < ... >
  TabLineTrunc       = { link = "TabLineFill", default = true },
  -- Separator between tabs
  TabLineSep         = { link = "TabLineFill", default = true },
}

--- (Re)apply every highlight group.
--- Called on setup and on ColorScheme autocmd.
function M.setup()
  for name, opts in pairs(groups) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

--- Override a specific group (useful for users in their setup()).
---@param name string
---@param opts table
function M.override(name, opts)
  groups[name] = opts
  vim.api.nvim_set_hl(0, name, opts)
end

return M
