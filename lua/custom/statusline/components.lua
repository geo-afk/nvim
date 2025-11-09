-- Statusline components (optimized with lualine-inspired caching/events)

local utils = require 'utils'
local get_opt = vim.api.nvim_get_option_value
local hl_str = utils.hl_str
local get_hl_hex = utils.get_hl_hex
local animation = require('custom.statusline.animation')

local M = {}

local group_number = function(num, sep)
  if num < 999 then
    return tostring(num)
  else
    num = tostring(num)
    return num:reverse():gsub('(%d%d%d)', '%1' .. sep):reverse():gsub('^,', '')
  end
end

-- Supported filetypes for lang version (cond check)
local supported_fts = {
  py = true, lua = true, go = true, rs = true, js = true, ts = true,
  jsx = true, tsx = true, java = true, vue = true, ex = true, exs = true,
}

-- Direct commands and parsers for lang versions
local lang_commands = {
  py = { 'python', '--version' },
  lua = { 'lua', '-v' },
  go = { 'go', 'version' },
  rs = { 'rustc', '--version' },
  js = { 'node', '--version' },
  ts = { 'node', '--version' },
  java = { 'java', '-version' },
  vue = { 'node', '--version' },
  ex = { 'elixir', '-v' },
  exs = { 'elixir', '-v' },
}

local lang_parsers = {
  py = function(out) return out:match('Python%s+(%d[^%s]+)') or 'v?' end,
  lua = function(out) return out:match('Lua%s+(%d[^%s]+)') or 'v?' end,
  go = function(out) return out:match('go(%d[^%s]+)') or 'v?' end,
  rs = function(out) return out:match('rustc%s+(%d[^%s]+)') or 'v?' end,
  js = function(out) return out:match('v(%d[^%s]+)') or 'v?' end,
  ts = function(out) return out:match('v(%d[^%s]+)') or 'v?' end,
  java = function(out) return out:match('version%s+"([^"]+)"') or 'v?' end,
  vue = function(out) return out:match('v(%d[^%s]+)') or 'v?' end,
  ex = function(out) return out:match('Erlang/OTP%s+(%d[^%s]+)') or 'v?' end,
  exs = function(out) return out:match('Erlang/OTP%s+(%d[^%s]+)') or 'v?' end,
}

-- Global lang cache (per-ft)
_G.lang_versions = {}
_G.lang_versions_pending = {}

local function get_lang_version_async(filetype)
  local ft_key = filetype
  if supported_fts[ft_key] and not _G.lang_versions[ft_key] and not _G.lang_versions_pending[ft_key] then
    _G.lang_versions_pending[ft_key] = true
    _G.lang_versions[ft_key] = 'loading...'
    vim.cmd('redrawstatus')

    local cmd = lang_commands[ft_key]
    vim.system(cmd, {text = true}, function(obj)
      _G.lang_versions_pending[ft_key] = nil
      if obj.code == 0 and lang_parsers[ft_key] then
        _G.lang_versions[ft_key] = lang_parsers[ft_key](obj.stdout)
      else
        _G.lang_versions[ft_key] = 'v?'
      end
      vim.schedule(function() vim.cmd('redrawstatus') end)
    end)
  end
end

-- Autocmd for lang (on FileType for cache hit)
vim.api.nvim_create_autocmd('FileType', {
  pattern = vim.tbl_keys(supported_fts),
  callback = function()
    local filetype = vim.bo.filetype
    get_lang_version_async(filetype)
  end,
  group = vim.api.nvim_create_augroup('idr4n/lang_version', { clear = true }),
})

local nonprog_modes = {
  ['markdown'] = true,
  ['org'] = true,
  ['text'] = true,
}

local isDark = vim.o.background == 'dark'

--- Gets the color for either insert or normal mode.
---@param mode "insert"|nil
---@return string
local function get_theme_color(mode)
  local ok, astrotheme = pcall(require, 'astrotheme')
  if not ok then
    return mode == 'insert' and '#A6E3A1' or '#89B4FA'
  end

  local colors = astrotheme.config.palette or {}

  if mode == 'insert' then
    return colors.green or '#A6E3A1'
  elseif mode == 'visual' then
    return colors.purple or '#CBA6F7'
  elseif mode == 'replace' then
    return colors.red or '#F38BA8'
  elseif mode == 'command' then
    return colors.yellow or '#F9E2AF'
  else
    return colors.blue or '#89B4FA'
  end
end

M.colors = {
  yellow = '#E2B86B',
  red = isDark and '#DE6E7C' or '#D73A4A',
  blue = get_theme_color(),
  insert = get_theme_color 'insert',
  select = isDark and '#FCA7EA' or '#2188FF',
  stealth = isDark and '#4E546B' or '#A7ACBF',
  fg_hl = isDark and '#FFAFF3' or '#9A5BFF',
  bg_hl = get_hl_hex('Normal').bg and utils.lighten(get_hl_hex('Normal').bg, 0.93) or 'none',
}

---Get a status decorator for some filetypes such as Nvimtree
---@return string
---@param opts? {name:string, align:string}
function M.decorator(opts)
  opts = vim.tbl_extend('force', { name = ' ', align = 'left' }, opts)
  local align = vim.tbl_contains({ 'left', 'right' }, opts.align) and opts.align or 'left'
  local name = ' ' .. opts.name .. ' '
  return (align == 'right' and '%=' or '') .. hl_str('SLDecorator', name)
end

---Keeps track of the highlight groups already created.
---@type table<string, boolean>
local statusline_hls = {}

---@param hl_bg? string
---@param hl_fg string
---@return string
function M.get_or_create_hl(hl_fg, hl_bg)
  hl_bg = hl_bg or 'Normal'
  local sanitized_hl_fg = hl_fg:gsub('#', '')
  local sanitized_hl_bg = hl_bg:gsub('#', '')
  local hl_name = 'SL' .. sanitized_hl_fg .. sanitized_hl_bg

  if not statusline_hls[hl_name] then
    local bg_hl
    if hl_bg:match '^#' then
      bg_hl = { bg = hl_bg }
    else
      bg_hl = vim.api.nvim_get_hl(0, { name = hl_bg })
    end

    local fg_hl
    if hl_fg:match '^#' then
      fg_hl = { fg = hl_fg }
    else
      fg_hl = vim.api.nvim_get_hl(0, { name = hl_fg })
    end

    if not bg_hl.bg then
      bg_hl = vim.api.nvim_get_hl(0, { name = 'Statusline' })
    end
    if not fg_hl.fg then
      fg_hl = vim.api.nvim_get_hl(0, { name = 'Statusline' })
    end

    vim.api.nvim_set_hl(0, hl_name, {
      bg = bg_hl.bg and (type(bg_hl.bg) == 'string' and bg_hl.bg or ('#%06x'):format(bg_hl.bg)) or 'none',
      fg = fg_hl.fg and (type(fg_hl.fg) == 'string' and fg_hl.fg or ('#%06x'):format(fg_hl.fg)) or 'none',
    })
    statusline_hls[hl_name] = true
  end

  return '%#' .. hl_name .. '#'
end

function M.reload_colors()
  statusline_hls = {}
  M.colors.bg_hl = get_hl_hex('Normal').bg and utils.lighten(get_hl_hex('Normal').bg, 0.93) or 'none'
  M.colors.blue = get_theme_color()
  M.colors.insert = get_theme_color 'insert'
end

---@return string
---@param opts? {mono:boolean}
function M.file_icon(opts)
  opts = opts or { mono = true }
  local devicons = require 'nvim-web-devicons'
  local icon, icon_highlight_group = devicons.get_icon(vim.fn.expand '%:t')
  if icon == nil then
    icon, icon_highlight_group = devicons.get_icon_by_filetype(vim.bo.filetype)
  end

  if icon == nil and icon_highlight_group == nil then
    icon = '󰈚'
    icon_highlight_group = 'DevIconDefault'
  end

  if not vim.bo.modifiable then
    icon = ''
    icon_highlight_group = 'SLNotModifiable'
  end

  return hl_str(icon_highlight_group, icon)
end

---@return string
---@param opts? {add_icon:boolean}
function M.fileinfo(opts)
  opts = opts or { add_icon = true }
  local icon = M.file_icon { mono = false }
  local dir = utils.pretty_dirpath()()
  local path = vim.fn.expand '%:t'
  local name = (path == '' and 'Empty ') or path:match '([^/\\]+)[/\\]*$'

  local modified = vim.bo.modified and hl_str('SLModified', ' ●') or ''
  local size = math.floor(vim.fn.getfsize(vim.fn.expand '%') / 1024) .. 'KB'

  return (dir ~= '' and ' ' .. dir .. '  ' or '') ..
      (opts.add_icon and icon .. ' ' or '') .. name .. modified .. ' [' .. size .. '] ' .. '%r%h%w'
end

local function get_vlinecount_str()
  local raw_count = vim.fn.line '.' - vim.fn.line 'v'
  raw_count = raw_count < 0 and raw_count - 1 or raw_count + 1

  return group_number(math.abs(raw_count), ',')
end

---Get wordcount for current buffer or visual selection (enhanced with diffs)
--- @return string word count
function M.get_fileinfo_widget()
  local ft = get_opt('filetype', {})
  local lines = group_number(vim.api.nvim_buf_line_count(0), ',')

  local wc_table = vim.fn.wordcount()

  if not nonprog_modes[ft] then
    if not wc_table.visual_words or not wc_table.visual_chars then
      return table.concat { hl_str('DiagnosticInfo', '≡'), ' ', lines, ' lines' }
    else
      return table.concat {
        hl_str('DiagnosticInfo', '‹›'),
        ' ' .. get_vlinecount_str() .. ' lines (+' .. group_number(wc_table.visual_chars - wc_table.chars, ',') .. ' chars)',
      }
    end
  end

  if not wc_table.visual_words or not wc_table.visual_chars then
    return table.concat {
      hl_str('DiagnosticInfo', '≡'),
      ' ' .. lines .. ' lines  ' .. group_number(wc_table.words, ',') .. ' words',
    }
  else
    return table.concat {
      hl_str('DiagnosticInfo', '‹›'),
      ' ' .. get_vlinecount_str() .. ' lines  ' .. group_number(wc_table.visual_words, ',') .. ' words  ' ..
      group_number(wc_table.visual_chars, ',') .. ' chars',
    }
  end
end

function M.padding(nr)
  nr = nr or 1
  return string.rep(' ', nr)
end

function M.get_position()
  return '%3l:%-2c '
end

function M.search_count()
  if vim.v.hlsearch == 0 then
    return ''
  end

  local ok, count = pcall(vim.fn.searchcount, { recompute = true, maxcount = 500 })
  if (not ok or (count.current == nil)) or (count.total == 0) then
    return ''
  end

  if count.incomplete == 1 then
    return hl_str('SLMatches', ' ?/? ')
  end

  local too_many = ('>%d'):format(count.maxcount)
  local total = (((count.total > count.maxcount) and too_many) or count.total)

  return hl_str('SLMatches', (' %s/%s '):format(count.current, total))
end

function M.maximized_status()
  return vim.b.is_zoomed and hl_str('SLModified', '  ') or ''
end

local function stbufnr()
  return vim.api.nvim_get_current_buf()
end

-- Cached LSP (per-buffer; dynamic staleness for large files)
function M.LSP()
  if not vim.b.status_cache then vim.b.status_cache = {} end
  local cache = vim.b.status_cache.lsp
  local now = vim.loop.now()
  local lines = vim.api.nvim_buf_line_count(0)
  local stale_threshold = (lines > 10000) and 10000 or 5000  -- 10s for large files

  if not cache or (now - (cache.timestamp or 0)) > stale_threshold then
    if rawget(vim, 'lsp') then
      local padding = 1
      local clients = {}
      for _, client in ipairs(vim.lsp.get_clients()) do
        if client.attached_buffers[stbufnr()] and client.name ~= 'null-ls' then
          table.insert(clients, client.name)
        end
      end
      if #clients > 0 then
        local names = table.concat(clients, ', ')
        cache = {
          str = (vim.o.columns > 120 and ' 󰄭  ' .. names .. string.rep(' ', padding)) or
                (' 󰄭  ' .. #clients .. ' LSP' .. string.rep(' ', padding)),
          timestamp = now,
        }
      else
        cache = { str = '', timestamp = now }
      end
    else
      cache = { str = '', timestamp = now }
    end
    vim.b.status_cache.lsp = cache
  end

  return cache.str
end

function M.show_macro_recording()
  local sep_left = M.get_or_create_hl('#ff6666', 'StatusLine') .. '█'
  local sep_right = M.get_or_create_hl('#ff6666', 'StatusLine') .. '█%* '

  local recording_register = vim.fn.reg_recording()
  if recording_register == '' then
    return ''
  else
    return sep_left .. M.get_or_create_hl('#212121', '#ff6666') .. '󰑋 ' .. recording_register .. sep_right
  end
end

-- Cached Git (per-buffer; dynamic staleness)
function M.git_status_simple()
  if not vim.b.status_cache then vim.b.status_cache = {} end
  local cache = vim.b.status_cache.git
  local now = vim.loop.now()
  local lines = vim.api.nvim_buf_line_count(0)
  local stale_threshold = (lines > 10000) and 10000 or 5000

  if not cache or (now - (cache.timestamp or 0)) > stale_threshold then
    local gitsigns = vim.b.gitsigns_status_dict
    if not gitsigns then
      cache = { str = '', timestamp = now }
    else
      local icons = { added = '', changed = '󰦒', removed = '' }
      local separator = ' │ '
      local segments = {}

      if gitsigns.added and gitsigns.added > 0 then
        table.insert(segments, M.get_or_create_hl('GitSignsAdd', 'StatusLine') .. icons.added .. ' ' .. gitsigns.added .. ' ')
      end

      if gitsigns.changed and gitsigns.changed > 0 then
        table.insert(segments,
          M.get_or_create_hl('GitSignsChange', 'StatusLine') .. icons.changed .. ' ' .. gitsigns.changed .. ' ')
      end

      if gitsigns.removed and gitsigns.removed > 0 then
        table.insert(segments,
          M.get_or_create_hl('GitSignsDelete', 'StatusLine') .. icons.removed .. ' ' .. gitsigns.removed .. ' ')
      end

      local str = #segments == 0 and '' or (separator .. table.concat(segments, separator) .. separator)
      cache = { str = str, timestamp = now }
    end
    vim.b.status_cache.git = cache
  end

  return cache.str
end

-- Cached Git Branch (per-buffer; lightweight)
function M.git_branch()
  if not vim.b.status_cache then vim.b.status_cache = {} end
  local cache = vim.b.status_cache.git_branch
  local now = vim.loop.now()
  local lines = vim.api.nvim_buf_line_count(0)
  local stale_threshold = (lines > 10000) and 10000 or 5000

  if not cache or (now - (cache.timestamp or 0)) > stale_threshold then
    local branch = vim.b.gitsigns_status_dict or { head = '' }
    local git_icon = ' '
    local is_head_empty = (branch.head ~= '')
    local str = is_head_empty and string.format(' %s%s ', git_icon, (branch.head or '')) or ''
    cache = { str = str, timestamp = now }
    vim.b.status_cache.git_branch = cache
  end

  return cache.str
end

-- Cond: Supported ft only
function M.lang_version()
  local filetype = vim.bo.filetype
  if not supported_fts[filetype] or vim.o.columns < 100 then return '' end
  local lang_v = _G.lang_versions[filetype]
  return lang_v and ' (' .. filetype .. ' ' .. lang_v .. ') ' or ''
end

-- Cached Diagnostics (per-buffer; dynamic staleness)
function M.lsp_diagnostics_simple()
  if not vim.b.status_cache then vim.b.status_cache = {} end
  local cache = vim.b.status_cache.diagnostics
  local now = vim.loop.now()
  local lines = vim.api.nvim_buf_line_count(0)
  local stale_threshold = (lines > 10000) and 10000 or 5000

  if not cache or (now - (cache.timestamp or 0)) > stale_threshold then
    local function get_severity(s)
      return #vim.diagnostic.get(0, { severity = s })
    end

    local result = {
      errors = get_severity(vim.diagnostic.severity.ERROR),
      warnings = get_severity(vim.diagnostic.severity.WARN),
      info = get_severity(vim.diagnostic.severity.INFO),
      hints = get_severity(vim.diagnostic.severity.HINT),
    }

    local total = result.errors + result.warnings + result.hints + result.info
    local errors = ''
    local warnings = ''
    local info = ''
    local hints = ''

    local icon = '▫'

    if result.errors > 0 then
      errors = M.get_or_create_hl('DiagnosticError', 'StatusLine') .. icon
    end
    if result.warnings > 0 then
      warnings = M.get_or_create_hl('DiagnosticWarn', 'StatusLine') .. icon
    end
    if result.info > 0 then
      info = M.get_or_create_hl('DiagnosticInfo', 'StatusLine') .. icon
    end
    if result.hints > 0 then
      hints = M.get_or_create_hl('DiagnosticHint', 'StatusLine') .. icon
    end

    local str = vim.bo.modifiable and total > 0 and (warnings .. errors .. info .. hints .. ' (' .. total .. ') ') or ''
    cache = { str = str, timestamp = now }
    vim.b.status_cache.diagnostics = cache
  end

  return cache.str
end

-- Conditional Scrollbar2 (hide on narrow/large files for perf)
function M.scrollbar2()
  local lines = vim.api.nvim_buf_line_count(0)
  if vim.o.columns < 80 or lines > 10000 then
    return hl_str('SLScrollbar', ' %l/%L ')  -- Cheap line fallback
  end

  local sbar_chars = { '󰋙', '󰫃', '󰫄', '󰫅', '󰫆', '󰫇', '󰫈' }

  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines_total = vim.api.nvim_buf_line_count(0)

  local i = math.floor((cur_line - 1) / lines_total * #sbar_chars) + 1
  local sbar = sbar_chars[i]

  if animation.enabled then
    sbar = animation.animate_scrollbar(sbar)
  end

  return hl_str('SLScrollbar', ' ' .. sbar .. ' ')
end

---Indicates whether a terminal is open or not
function M.terminal_status()
  local is_terminal_open = false
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      is_terminal_open = true
    end
  end
  return is_terminal_open and M.get_or_create_hl('SLBgNoneHl', 'StatusLine') .. '  ' .. '%* ' or ''
end

function M.lsp_progress()
  local msg = require('utils.lsp_progress').get_progress()
  return msg ~= '' and (' ' .. msg .. ' ') or ''
end

-- Cond: Non-default only; width check
function M.meta_info()
  if vim.o.columns < 120 then return '' end
  local parts = {}
  if vim.o.fileencoding ~= '' and vim.o.fileencoding ~= 'utf-8' then
    table.insert(parts, vim.o.fileencoding:upper())
  end
  if vim.bo.fileformat ~= 'unix' then
    table.insert(parts, vim.bo.fileformat:upper())
  end
  if vim.wo.spell then
    table.insert(parts, 'SPELL:✓')
  end
  if vim.o.paste then
    table.insert(parts, 'PASTE:✓')
  end
  return #parts > 0 and hl_str('SLDim', table.concat(parts, ' │ ')) or ''
end

-- Invalidate caches on buffer events (lualine-inspired)
local function invalidate_caches()
  vim.b.status_cache = nil  -- Per-buffer reset
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType', 'BufWritePost' }, {
  callback = invalidate_caches,
  group = vim.api.nvim_create_augroup('StatuslineCache', { clear = true }),
})

return M