local ut = require 'utils'
local c = require 'custom.statusline.components'
local colors = c.colors
local animation = require 'custom.statusline.animation'
local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
local statusline_hl = vim.api.nvim_get_hl(0, { name = 'StatusLine' })
local fg_lighten = normal_hl.bg and ut.darken(string.format('#%06x', normal_hl.bg), 0.6) or colors.stealth

-- Enable lazyredraw globally for smooth navigation (toggleable)
vim.o.lazyredraw = true

-- Enhanced modern color palette (TokyoNight-inspired)
local modern_colors = {
  normal = '#7AA2F7',
  insert = '#9ECE6A',
  visual = '#BB9AF7',
  replace = '#F7768E',
  command = '#E0AF68',
  terminal = '#73DACA',

  bg_darker = statusline_hl.bg and string.format('#%06x', statusline_hl.bg) or '#1a1b26',
  bg_lighter = '#24283b',
  fg_main = '#c0caf5',
  fg_dim = '#565f89',
  accent = '#7dcfff',

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

local function create_mode_hl(name, bg_color)
  vim.api.nvim_set_hl(0, 'Status' .. name, { bg = bg_color, fg = '#1a1b26', bold = true })
  vim.api.nvim_set_hl(0, 'Status' .. name .. 'Inv', { fg = bg_color, bg = statusline_hl.bg, bold = true })
end
create_mode_hl('Normal', modern_colors.normal)
create_mode_hl('Insert', modern_colors.insert)
create_mode_hl('Visual', modern_colors.visual)
create_mode_hl('Replace', modern_colors.replace)
create_mode_hl('Command', modern_colors.command)
create_mode_hl('Terminal', modern_colors.terminal)

vim.api.nvim_set_hl(0, 'SLAccent', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'SLDim', { fg = modern_colors.fg_dim, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLFileInfo', { fg = modern_colors.fg_main, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, 'SLPosition', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = false })
vim.api.nvim_set_hl(0, 'SLFiletype', { fg = modern_colors.fg_dim, bg = statusline_hl.bg, italic = true })
vim.api.nvim_set_hl(0, 'SLScrollbar', { fg = modern_colors.accent, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, 'SLSeparator', { fg = modern_colors.fg_dim, bg = statusline_hl.bg })

-- Full mode map (static)
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
  local info = mode_map[mode] or { name = 'UNKNOWN', hl = 'StatusNormal', hl_inv = 'StatusNormalInv', icon = '󰋜' }
  if animation.enabled then
    local animated_bg = animation.animate_mode(modern_colors.normal)
    vim.api.nvim_set_hl(0, info.hl, { bg = animated_bg, fg = '#1a1b26', bold = true })
  end
  return info
end

-- Mode indicator (flat block)
local function mode_indicator()
  local mode_info = get_mode_info()
  local sep_right = '%#' .. mode_info.hl_inv .. '# │'

  return table.concat {
    '%#' .. mode_info.hl .. '#█',
    ' ',
    mode_info.icon,
    ' ',
    mode_info.name,
    ' ',
    sep_right,
  }
end

local function separator()
  return '%#SLSeparator# │ %*'
end

-- Throttled redraw (500ms for large files perf)
local refresh_timer = nil
local function throttled_redraw()
  if refresh_timer then refresh_timer:stop() end
  local lines = vim.api.nvim_buf_line_count(0)
  local delay = (lines > 10000) and 500 or 250
  refresh_timer = vim.loop.new_timer()
  refresh_timer:start(delay, 0, vim.schedule_wrap(function()
    vim.cmd('redrawstatus')
    refresh_timer:stop()
  end))
end

-- WinScrolled for scroll-only updates (less jitter than BufEnter)
vim.api.nvim_create_autocmd({ 'ModeChanged', 'DiagnosticChanged', 'WinScrolled', 'FileType', 'BufWritePost' }, {
  callback = function() vim.schedule(throttled_redraw) end,
  group = vim.api.nvim_create_augroup('StatuslineAsync', { clear = true }),
})

---@return string
function Status_line()
  local filetype = vim.bo.filetype
  local filetypes = { 'neo-tree', 'minifiles', 'oil', 'TelescopePrompt', 'fzf', 'snacks_picker_input' }

  if vim.tbl_contains(filetypes, filetype) then
    local home_dir = vim.loop.os_homedir() or ''
    local dir = vim.fn.getcwd()
    dir = dir:gsub('^' .. home_dir, '~')
    local ft = filetype:sub(1, 1):upper() .. filetype:sub(2)
    return c.decorator { name = ft .. ': ' .. dir, align = 'left' }
  end

  local components = {
    mode_indicator(),
    c.padding(1),
    c.git_branch(),             -- Cached
    c.git_status_simple(),      -- Cached
    c.fileinfo { add_icon = true },
    c.lsp_diagnostics_simple(), -- Cached
    -- c.LSP(),  -- Cached

    -- vim.o.columns > 100 and c.get_fileinfo_widget() or '',

    '%=',

    c.maximized_status(),
    c.show_macro_recording(),
    c.lsp_progress(),
    c.terminal_status(),
    c.search_count(),
    -- c.lang_version(), -- Cond + cached
    separator(),
    '%#SLPosition#' .. c.get_position() .. '%*',
    separator(),
    '%#SLFiletype#' .. vim.bo.filetype:lower() .. '%*',
    c.meta_info(),                              -- Cond
    c.padding(1),
    '%#SLScrollbar#' .. c.scrollbar2() .. '%*', -- Conditional
    c.padding(1),
  }

  return table.concat(components)
end

-- Toggles
function _G.toggle_statusline_animation()
  animation.toggle()
end

vim.keymap.set('n', '<leader>sa', _G.toggle_statusline_animation, { desc = 'Toggle Statusline Animation' })

function _G.toggle_lazyredraw()
  vim.o.lazyredraw = not vim.o.lazyredraw
  print('lazyredraw: ' .. tostring(vim.o.lazyredraw))
end

vim.keymap.set('n', '<leader>lr', _G.toggle_lazyredraw, { desc = 'Toggle Lazy Redraw' })

vim.o.statusline = '%!luaeval("Status_line()")'

