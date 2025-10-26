local ut = require 'utils'
local c = require 'custom.statusline.components'
local colors = c.colors
local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
local statusline_hl = vim.api.nvim_get_hl(0, { name = 'StatusLine' })
local fg_lighten = normal_hl.bg and ut.darken(string.format('#%06x', normal_hl.bg), 0.6) or colors.stealth

-- Modern color palette
local modern_colors = {
  -- Mode colors - vibrant and distinct
  normal = '#7AA2F7', -- Cool blue
  insert = '#9ECE6A', -- Fresh green
  visual = '#BB9AF7', -- Purple
  replace = '#F7768E', -- Coral red
  command = '#E0AF68', -- Golden yellow
  terminal = '#73DACA', -- Teal

  -- UI colors
  bg_darker = statusline_hl.bg and string.format('#%06x', statusline_hl.bg) or '#1a1b26',
  bg_lighter = '#24283b',
  fg_main = '#c0caf5',
  fg_dim = '#565f89',
  accent = '#7dcfff',

  -- Status colors
  git_add = '#9ece6a',
  git_change = '#e0af68',
  git_delete = '#f7768e',
  diagnostic_error = '#f7768e',
  diagnostic_warn = '#e0af68',
  diagnostic_info = '#7dcfff',
  diagnostic_hint = '#1abc9c',
}

-- Create highlight groups
vim.api.nvim_set_hl(0, 'SLBgNoneHl', { fg = colors.fg_hl, bg = 'none' })
vim.api.nvim_set_hl(0, 'SLNotModifiable', { fg = colors.yellow, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLNormal', { fg = fg_lighten, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLModified', { fg = '#FF7EB6', bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLMatches', { fg = colors.bg_hl, bg = colors.fg_hl })
vim.api.nvim_set_hl(0, 'SLDecorator', { fg = '#1a1b26', bg = '#7AA2F7', bold = true })

-- Mode-specific highlights (background)
vim.api.nvim_set_hl(0, 'StatusNormal', { bg = modern_colors.normal, fg = '#1a1b26', bold = true })
vim.api.nvim_set_hl(0, 'StatusInsert', { bg = modern_colors.insert, fg = '#1a1b26', bold = true })
vim.api.nvim_set_hl(0, 'StatusVisual', { bg = modern_colors.visual, fg = '#1a1b26', bold = true })
vim.api.nvim_set_hl(0, 'StatusReplace', { bg = modern_colors.replace, fg = '#1a1b26', bold = true })
vim.api.nvim_set_hl(0, 'StatusCommand', { bg = modern_colors.command, fg = '#1a1b26', bold = true })
vim.api.nvim_set_hl(0, 'StatusTerminal', { bg = modern_colors.terminal, fg = '#1a1b26', bold = true })

-- Mode-specific highlights (foreground/inverted)
vim.api.nvim_set_hl(0, 'StatusNormalInv', { fg = modern_colors.normal, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'StatusInsertInv', { fg = modern_colors.insert, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'StatusVisualInv', { fg = modern_colors.visual, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'StatusReplaceInv', { fg = modern_colors.replace, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'StatusCommandInv', { fg = modern_colors.command, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'StatusTerminalInv', { fg = modern_colors.terminal, bg = statusline_hl.bg, bold = true })

-- Modern right section highlights
vim.api.nvim_set_hl(0, 'SLAccent', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'SLDim', { fg = modern_colors.fg_dim, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLFileInfo', { fg = modern_colors.fg_main, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLPosition', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = false })
vim.api.nvim_set_hl(0, 'SLFiletype', { fg = modern_colors.fg_dim, bg = statusline_hl.bg, italic = true })
vim.api.nvim_set_hl(0, 'SLScrollbar', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'SLSeparator', { fg = modern_colors.fg_dim, bg = statusline_hl.bg })

-- Get current mode information
local function get_mode_info()
  local mode_map = {
    ['n'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['no'] = { name = 'N·OP', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['nov'] = { name = 'N·OP', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['noV'] = { name = 'N·OP', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['no\22'] = { name = 'N·OP', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['niI'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['niR'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['niV'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['nt'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['ntT'] = { name = 'NORMAL', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' },
    ['v'] = { name = 'VISUAL', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['vs'] = { name = 'VISUAL', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['V'] = { name = 'V·LINE', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['Vs'] = { name = 'V·LINE', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['\22'] = { name = 'V·BLOCK', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['\22s'] = { name = 'V·BLOCK', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰈈' },
    ['s'] = { name = 'SELECT', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰒅' },
    ['S'] = { name = 'S·LINE', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰒅' },
    ['\19'] = { name = 'S·BLOCK', hl = 'StatusVisual', hl_inv = 'StatusVisualInv', icon = '󰒅' },
    ['i'] = { name = 'INSERT', hl = 'StatusInsert', hl_inv = 'StatusInsertInv', icon = '󰏫' },
    ['ic'] = { name = 'INSERT', hl = 'StatusInsert', hl_inv = 'StatusInsertInv', icon = '󰏫' },
    ['ix'] = { name = 'INSERT', hl = 'StatusInsert', hl_inv = 'StatusInsertInv', icon = '󰏫' },
    ['R'] = { name = 'REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['Rc'] = { name = 'REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['Rx'] = { name = 'REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['Rv'] = { name = 'V·REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['Rvc'] = { name = 'V·REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['Rvx'] = { name = 'V·REPLACE', hl = 'StatusReplace', hl_inv = 'StatusReplaceInv', icon = '󰛔' },
    ['c'] = { name = 'COMMAND', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰘳' },
    ['cv'] = { name = 'COMMAND', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰘳' },
    ['ce'] = { name = 'COMMAND', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰘳' },
    ['r'] = { name = 'PROMPT', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰋗' },
    ['rm'] = { name = 'MORE', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰋗' },
    ['r?'] = { name = 'CONFIRM', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰋗' },
    ['!'] = { name = 'SHELL', hl = 'StatusCommand', hl_inv = 'StatusCommandInv', icon = '󰆍' },
    ['t'] = { name = 'TERMINAL', hl = 'StatusTerminal', hl_inv = 'StatusTerminalInv', icon = '󰆍' },
  }

  local mode = vim.api.nvim_get_mode().mode
  return mode_map[mode] or { name = 'UNKNOWN', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' }
end

-- Mode indicator component
local function mode_indicator()
  local mode_info = get_mode_info()
  local sep_right = '%#' .. mode_info.hl_inv .. '#' .. ''

  return table.concat {
    '%#' .. mode_info.hl .. '#',
    ' ',
    mode_info.icon,
    ' ',
    mode_info.name,
    ' ',
    sep_right,
  }
end

-- Modern separator component
local function separator()
  return '%#SLSeparator# · %*'
end

---@return string
function Status_line()
  local filetype = vim.bo.filetype
  local filetypes = { 'neo-tree', 'minifiles', 'NvimTree', 'oil', 'TelescopePrompt', 'fzf', 'snacks_picker_input' }

  if vim.tbl_contains(filetypes, filetype) then
    local home_dir = os.getenv 'HOME'
    local api = require 'nvim-tree.api'
    local node = api.tree.get_node_under_cursor()
    local dir = filetype == 'NvimTree' and node.absolute_path or vim.fn.getcwd()
    dir = dir:gsub('^' .. home_dir, '~')
    local ft = filetype:sub(1, 1):upper() .. filetype:sub(2)
    return c.decorator { name = ft .. ': ' .. dir, align = 'left' }
  end

  local components = {
    -- Left section
    mode_indicator(),
    c.padding(),
    c.git_branch(),
    c.git_status_simple(),
    c.fileinfo { add_icon = false }, -- REMOVED ICON HERE
    c.lsp_diagnostics_simple(),

    -- Middle/Right align
    '%=',

    -- Right section - modernized and cleaner
    c.maximized_status(),
    c.show_macro_recording(),
    c.lsp_progress(),
    c.terminal_status(),
    c.search_count(),
    separator(),
    '%#SLPosition#' .. c.get_position() .. '%*',
    separator(),
    '%#SLFiletype#' .. vim.bo.filetype:lower() .. '%*',
    c.padding(),
    '%#SLScrollbar#' .. c.scrollbar2() .. '%*',
    c.padding(),
  }

  return table.concat(components)
end

vim.o.statusline = '%!luaeval("Status_line()")'
