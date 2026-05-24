-- =============================================================================
-- statusline/components/mode.lua
-- Current Neovim mode: label, icon, highlight group.
-- =============================================================================

local M = {}
local hl = require("custom.statusline.highlights").hl

-- ---------------------------------------------------------------------------
-- Mode table: [short_code] = { label, icon, hl }
-- ---------------------------------------------------------------------------
local modes = {
  -- Normal family
  ["n"] = { label = "NORMAL", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["no"] = { label = "N·OP", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["nov"] = { label = "N·OP", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["noV"] = { label = "N·OP", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["no\22"] = { label = "N·OP", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["niI"] = { label = "NORMAL", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["niR"] = { label = "NORMAL", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["niV"] = { label = "NORMAL", icon = "󰋜 ", hl = "StatusLineNormal" },
  ["nt"] = { label = "NORMAL", icon = "󰋜 ", hl = "StatusLineNormal" },

  -- Insert family
  ["i"] = { label = "INSERT", icon = "󰏫 ", hl = "StatusLineInsert" },
  ["ic"] = { label = "INSERT", icon = "󰏫 ", hl = "StatusLineInsert" },
  ["ix"] = { label = "INSERT", icon = "󰏫 ", hl = "StatusLineInsert" },

  -- Visual family
  ["v"] = { label = "VISUAL", icon = "󰈈 ", hl = "StatusLineVisual" },
  ["vs"] = { label = "VISUAL", icon = "󰈈 ", hl = "StatusLineVisual" },
  ["V"] = { label = "V·LINE", icon = "󰈈 ", hl = "StatusLineVisual" },
  ["Vs"] = { label = "V·LINE", icon = "󰈈 ", hl = "StatusLineVisual" },
  ["\22"] = { label = "V·BLOCK", icon = "󰈈 ", hl = "StatusLineVisual" },
  ["\22s"] = { label = "V·BLOCK", icon = "󰈈 ", hl = "StatusLineVisual" },

  -- Select family
  ["s"] = { label = "SELECT", icon = " ", hl = "StatusLineSelect" },
  ["S"] = { label = "S·LINE", icon = " ", hl = "StatusLineSelect" },
  ["\19"] = { label = "S·BLOCK", icon = " ", hl = "StatusLineSelect" },

  -- Replace family
  ["R"] = { label = "REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },
  ["Rc"] = { label = "REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },
  ["Rx"] = { label = "REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },
  ["Rv"] = { label = "V·REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },
  ["Rvc"] = { label = "V·REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },
  ["Rvx"] = { label = "V·REPLACE", icon = "󰊄 ", hl = "StatusLineReplace" },

  -- Command
  ["c"] = { label = "COMMAND", icon = " ", hl = "StatusLineCommand" },
  ["cv"] = { label = "EX", icon = " ", hl = "StatusLineCommand" },
  ["ce"] = { label = "EX", icon = " ", hl = "StatusLineCommand" },
  ["r"] = { label = "PROMPT", icon = " ", hl = "StatusLineCommand" },
  ["rm"] = { label = "MORE", icon = " ", hl = "StatusLineCommand" },
  ["r?"] = { label = "CONFIRM", icon = " ", hl = "StatusLineCommand" },
  ["!"] = { label = "SHELL", icon = " ", hl = "StatusLineCommand" },

  -- Terminal
  ["t"] = { label = "TERMINAL", icon = " ", hl = "StatusLineTerminal" },
}

--- Resolve mode info, with a safe fallback for unmapped codes.
local function get_mode_info()
  local code = vim.api.nvim_get_mode().mode
  return modes[code] or { label = code:upper(), icon = "? ", hl = "StatusLineNormal" }
end

--- Render the mode pill:  <icon> LABEL
--- Returns the rendered string and the active mode highlight name
--- so downstream components can also use the colour.
function M.render(winid, width)
  local win_width = width or (winid and vim.api.nvim_win_get_width(winid)) or 100
  local info = get_mode_info()
  local label = win_width > 50 and info.label or ""
  local pill = hl(info.hl) .. info.icon .. label .. hl("StatusLine")
  return pill, info.hl
end

function M.variants(ctx)
  local win_width = ctx.width or 100
  local info = get_mode_info()
  local label = win_width > 50 and info.label or ""
  local full = hl(info.hl) .. info.icon .. label .. hl("StatusLine")
  local icon = hl(info.hl) .. info.icon:gsub("%s+$", "") .. hl("StatusLine")
  return {
    { name = "full", text = full },
    { name = "icon", text = icon },
  }
end

--- Returns just the active highlight group name (for other components to use).
function M.active_hl()
  return get_mode_info().hl
end

return M
