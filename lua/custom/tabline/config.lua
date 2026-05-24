-- tabline/config.lua
-- Holds default configuration and the apply() merge helper.

local M = {}

---@class TablineConfig
---@field max_buffers      integer  Maximum number of buffer tabs shown at once (0 = unlimited)
---@field max_name_length  integer  Truncate filenames longer than this (0 = unlimited)
---@field padding          integer  Spaces on each side of a tab label
---@field close_icon       string   Close button character
---@field separator        string   Character between tabs (empty string = none)
---@field show_close       boolean  Whether to show the close button
---@field show_bufnr       boolean  Whether to show the buffer number in tabs
---@field show_readonly    boolean  Whether to show a lock icon for readonly buffers
---@field focus_on_close   string   Which buffer to focus after closing: "left"|"right"|"previous"
---@field keymaps          table    Keymap strings; set a key to false to disable

M.defaults = {
  max_buffers = 20,
  max_name_length = 24,
  padding = 1,
  -- Premium Close Icon options (copy/paste into close_icon below):
  --   "✘" (Standard bold cross)
  --   "󰅖" (Nerd Font square cross)
  --   "󰅶" (Nerd Font circle cross)
  --   "󰅱" (Nerd Font cancel button)
  --   "" (Nerd Font thin cross)
  --   "" (Nerd Font minus/remove circle)
  --   "" (Nerd Font diagonal cross)
  close_icon = "✘",
  separator = "", -- space between tabs
  show_close = true,
  show_bufnr = false, -- Default to false (buffer numbers removed as requested)
  show_readonly = true,
  focus_on_close = "left", -- "left" | "right" | "previous"

  keymaps = {
    next = "<Tab>",
    prev = "<S-Tab>",
    close = "<A-c>",
  },
}

--- Deep-merge user config over defaults.
---@param user_config table|nil
---@return TablineConfig
function M.apply(user_config)
  return vim.tbl_deep_extend("force", M.defaults, user_config or {})
end

return M
