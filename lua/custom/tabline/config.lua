-- tabline/config.lua
-- Holds default configuration and the apply() merge helper.
-- Nothing here has side-effects; it is a pure data module.

local M = {}

---@class TablineConfig
---@field max_buffers      integer  Maximum number of buffer tabs shown at once (0 = unlimited)
---@field max_name_length  integer  Truncate filenames longer than this (0 = unlimited)
---@field padding          integer  Spaces on each side of a tab label
---@field close_icon       string   Close button character
---@field separator        string   Character between tabs (empty string = none)
---@field show_close       boolean  Whether to show the close button
---@field focus_on_close   string   Which buffer to focus after closing: "left"|"right"|"previous"
---@field keymaps          table    Keymap strings; set a key to false to disable

M.defaults = {
  max_buffers = 20,
  max_name_length = 24,
  padding = 1,
  close_icon = "✘",
  separator = "", -- between tabs; "" = none, "│" = thin bar, etc.
  show_close = true,
  focus_on_close = "left", -- "left" | "right" | "previous"

  keymaps = {
    next = "<Tab>",
    prev = "<S-Tab>",
    close = "<A-c>",
    -- move_left = "<leader>b<",
    -- move_right = "<leader>b>",
  },
}

--- Deep-merge user config over defaults.
--- Users only need to supply keys they want to override.
---@param user_config table|nil
---@return TablineConfig
function M.apply(user_config)
  return vim.tbl_deep_extend("force", M.defaults, user_config or {})
end

return M
