-- =============================================================================
-- statusline/components/mode.lua
-- Current Neovim mode: label, icon, highlight group.
-- =============================================================================

local M = {}
local hl = require('custom.statusline.highlights').hl

-- ---------------------------------------------------------------------------
-- Mode table: [short_code] = { label, icon, hl, sep_hl }
-- ---------------------------------------------------------------------------
local modes = {
  -- Normal family
  ['n'] = { label = 'NORMAL', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['no'] = { label = 'N·OP', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['nov'] = { label = 'N·OP', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['noV'] = { label = 'N·OP', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['no\22'] = { label = 'N·OP', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['niI'] = { label = 'NORMAL', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['niR'] = { label = 'NORMAL', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['niV'] = { label = 'NORMAL', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },
  ['nt'] = { label = 'NORMAL', icon = '󰋜 ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' },

  -- Insert family
  ['i'] = { label = 'INSERT', icon = '󰏫 ', hl = 'StatusLineInsert', sep = 'StatusLineInsertSep' },
  ['ic'] = { label = 'INSERT', icon = '󰏫 ', hl = 'StatusLineInsert', sep = 'StatusLineInsertSep' },
  ['ix'] = { label = 'INSERT', icon = '󰏫 ', hl = 'StatusLineInsert', sep = 'StatusLineInsertSep' },

  -- Visual family
  ['v'] = { label = 'VISUAL', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },
  ['vs'] = { label = 'VISUAL', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },
  ['V'] = { label = 'V·LINE', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },
  ['Vs'] = { label = 'V·LINE', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },
  ['\22'] = { label = 'V·BLOCK', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },
  ['\22s'] = { label = 'V·BLOCK', icon = '󰈈 ', hl = 'StatusLineVisual', sep = 'StatusLineVisualSep' },

  -- Select family
  ['s'] = { label = 'SELECT', icon = ' ', hl = 'StatusLineSelect', sep = 'StatusLineSelectSep' },
  ['S'] = { label = 'S·LINE', icon = ' ', hl = 'StatusLineSelect', sep = 'StatusLineSelectSep' },
  ['\19'] = { label = 'S·BLOCK', icon = ' ', hl = 'StatusLineSelect', sep = 'StatusLineSelectSep' },

  -- Replace family
  ['R'] = { label = 'REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },
  ['Rc'] = { label = 'REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },
  ['Rx'] = { label = 'REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },
  ['Rv'] = { label = 'V·REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },
  ['Rvc'] = { label = 'V·REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },
  ['Rvx'] = { label = 'V·REPLACE', icon = '󰊄 ', hl = 'StatusLineReplace', sep = 'StatusLineReplaceSep' },

  -- Command
  ['c'] = { label = 'COMMAND', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['cv'] = { label = 'EX', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['ce'] = { label = 'EX', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['r'] = { label = 'PROMPT', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['rm'] = { label = 'MORE', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['r?'] = { label = 'CONFIRM', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },
  ['!'] = { label = 'SHELL', icon = ' ', hl = 'StatusLineCommand', sep = 'StatusLineCommandSep' },

  -- Terminal
  ['t'] = { label = 'TERMINAL', icon = ' ', hl = 'StatusLineTerminal', sep = 'StatusLineTermSep' },
}

local sep_right = '' -- powerline right-facing solid

--- Resolve mode info, with a safe fallback for unmapped codes.
local function get_mode_info()
  local code = vim.api.nvim_get_mode().mode
  return modes[code] or { label = code:upper(), icon = '? ', hl = 'StatusLineNormal', sep = 'StatusLineNormalSep' }
end

--- Render the mode pill:  <icon> LABEL
--- Returns the rendered string and the active mode highlight name
--- so downstream components can also use the colour.
function M.render()
  local info = get_mode_info()
  -- Pill: [MODE_HL] icon + label  [SEP_HL] powerline-sep [RESET]
  local pill = hl(info.hl) .. ' ' .. info.icon .. info.label .. ' ' .. hl(info.sep) .. sep_right .. hl 'StatusLine'
  return pill, info.hl
end

--- Returns just the active highlight group name (for other components to use).
function M.active_hl()
  return get_mode_info().hl
end

return M
