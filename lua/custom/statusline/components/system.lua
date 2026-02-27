-- =============================================================================
-- statusline/components/system.lua  (cached CWD edition)
-- =============================================================================
--
-- PERFORMANCE FIX
-- ────────────────
-- getcwd() + fnamemodify() were called on every eval(). They're now cached in
-- _cwd_cache and rebuilt only when DirChanged fires (via M.invalidate_cwd()).
--
-- Everything else (OS icon, paste/spell/wrap/macro) is cheap and stays live.
-- =============================================================================

local M = {}
local hl = require('custom.statusline.highlights').hl

-- ---------------------------------------------------------------------------
-- OS detection — computed exactly once at module load
-- ---------------------------------------------------------------------------
local os_icon = (function()
  local uname = (vim.uv or vim.loop).os_uname()
  local sysname = (uname.sysname or ''):lower()
  if sysname:find 'darwin' then
    return ' '
  elseif sysname:find 'windows' or sysname:find 'mingw' then
    return '󰍲 '
  else
    return ' '
  end
end)()

-- ---------------------------------------------------------------------------
-- CWD cache  (keyed by raw cwd string)
-- ---------------------------------------------------------------------------
local _cwd_cache = {} -- [cwd_raw] = { sm = str, lg = str }

function M.invalidate_cwd()
  _cwd_cache = {}
end

local function short_cwd(max_len)
  local raw = vim.fn.getcwd()
  local tier = max_len <= 20 and 'sm' or 'lg'

  if _cwd_cache[raw] and _cwd_cache[raw][tier] then
    return _cwd_cache[raw][tier]
  end

  local cwd = raw
  local home = vim.env.HOME or vim.env.USERPROFILE or ''
  if home ~= '' then
    cwd = cwd:gsub('^' .. vim.pesc(home), '~')
  end

  if #cwd > max_len then
    local parts = vim.split(cwd, '/', { plain = true })
    if #parts >= 2 then
      cwd = '…/' .. table.concat(parts, '/', math.max(1, #parts - 1))
    end
    if #cwd > max_len then
      cwd = '…' .. cwd:sub(-(max_len - 1))
    end
  end

  _cwd_cache[raw] = _cwd_cache[raw] or {}
  _cwd_cache[raw][tier] = cwd
  return cwd
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------
function M.render(winid)
  local win_width = vim.api.nvim_win_get_width(winid)
  local compact = win_width < 80
  local very_compact = win_width < 55
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local parts = {}

  -- Macro recording (always live — cheap fn call)
  local reg = vim.fn.reg_recording()
  if reg ~= '' then
    parts[#parts + 1] = hl 'StatusLineMacro' .. ' @' .. reg .. ' ' .. hl 'StatusLine'
  end

  -- Paste mode (option read — O(1))
  if vim.o.paste then
    parts[#parts + 1] = hl 'StatusLinePaste' .. ' PASTE ' .. hl 'StatusLine'
  end

  -- Spell
  if vim.wo[winid].spell then
    local lang = vim.bo[bufnr].spelllang or 'en'
    parts[#parts + 1] = hl 'StatusLineSpell' .. ' SPELL:' .. lang .. ' ' .. hl 'StatusLine'
  end

  -- Wrap (only show in full mode — avoid clutter)
  if not compact and vim.wo[winid].wrap then
    parts[#parts + 1] = hl 'StatusLineWrap' .. '↩ ' .. hl 'StatusLine'
  end

  if very_compact then
    return table.concat(parts, ' ')
  end

  -- OS icon (module-level constant — zero cost)
  parts[#parts + 1] = hl 'StatusLineOS' .. os_icon .. hl 'StatusLine'

  -- CWD (cached)
  if not compact then
    local max_cwd = math.min(30, math.floor(win_width * 0.15))
    parts[#parts + 1] = hl 'StatusLineCWD' .. short_cwd(max_cwd) .. hl 'StatusLine'
  end

  return ' ' .. table.concat(parts, ' ') .. ' '
end

return M
