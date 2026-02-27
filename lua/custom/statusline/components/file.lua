-- =============================================================================
-- statusline/components/file.lua  (cached edition)
-- =============================================================================
--
-- PERFORMANCE FIX
-- ────────────────
-- The previous version called getfsize(), fnamemodify(), buf_line_count(),
-- and built format strings on every single eval() call — i.e. on every
-- keypress and scroll step.
--
-- This version caches the full rendered string per bufnr.
-- The cache entry is rebuilt only when explicitly invalidated via M.invalidate()
-- or M.invalidate_all(), which are called from autocmds in init.lua:
--   • BufEnter, BufWritePost, BufReadPost  → M.invalidate(bufnr)
--   • OptionSet(fileencoding,fileformat)   → M.invalidate(bufnr)
--   • VimResized                           → M.invalidate_all()
--
-- The hot path (eval on every scroll) now does: one table lookup + return.
-- =============================================================================

local M = {}
local hl = require('custom.statusline.highlights').hl

-- ---------------------------------------------------------------------------
-- Cache:  [cache_key] = rendered_string
-- Cache key = bufnr .. ":" .. win_width_bucket
-- We bucket window widths into 3 tiers (very_compact / compact / full) so the
-- same buffer in windows of slightly different widths doesn't bust the cache,
-- but does rebuild when the display tier changes.
-- ---------------------------------------------------------------------------
local _cache = {}

local function width_bucket(w)
  if w < 55 then
    return 'xs'
  elseif w < 80 then
    return 'sm'
  else
    return 'lg'
  end
end

local function cache_key(bufnr, winid)
  return bufnr .. ':' .. width_bucket(vim.api.nvim_win_get_width(winid))
end

function M.invalidate(bufnr)
  -- Remove all width-tier entries for this buffer.
  for k in pairs(_cache) do
    if k:sub(1, #tostring(bufnr) + 1) == tostring(bufnr) .. ':' then
      _cache[k] = nil
    end
  end
end

function M.invalidate_all()
  _cache = {}
end

-- ---------------------------------------------------------------------------
-- Filetype icon map (Nerd Fonts v3)
-- ---------------------------------------------------------------------------
local ft_icons = {
  lua = '󰢱 ', -- already good
  python = '󰌠 ', -- already good (or ' ' / '󰌍 ')
  javascript = '󰌞 ', -- already good
  typescript = '󰛦 ', -- already good
  rust = '󱘗 ', -- already good (or ' ')
  go = '󰟓 ', -- already good (or ' ')
  c = ' ', -- classic C
  cpp = ' ', -- classic C++
  java = '󰬷 ', -- already good (or ' ')
  html = '󰌝 ', -- already good
  css = '󰌜 ', -- already good
  scss = '󰌜 ', -- already good (same as css)
  json = '󰘦 ', -- already good (or ' ')
  yaml = '󰘦 ', -- already good
  toml = '󰘦 ', -- already good
  markdown = '󰍔 ', -- already good (or ' ')
  vim = ' ', -- or ' ' / ' '
  sh = ' ', -- generic shell
  bash = ' ', -- bash (or ' ')
  zsh = ' ', -- zsh (often same as bash)
  fish = '󰈺 ', -- fish shell
  dockerfile = '󰡨 ', -- already good
  makefile = ' ', -- or ' '
  sql = '󰆼 ', -- already good (or ' ')
  tex = ' ', -- LaTeX
  help = '󰞋 ', -- already good
  nix = '󰍛 ', -- Nix (flake / snowflake vibe)
  svelte = ' ', -- common Svelte
  vue = '󰡄 ', -- already good (or ' ')
  tsx = '󰛦 ', -- already good (same as ts)
  jsx = '󰌞 ', -- already good (same as js)
  graphql = ' ', -- GraphQL
  php = '󰌟 ', -- already good
  ruby = '󰴭 ', -- or ' '
  elixir = ' ', -- Phoenix / Elixir
  haskell = '󰲒 ', -- already good
  scala = ' ', -- Scala
  kotlin = '󱈙 ', -- already good
  swift = '󰛥 ', -- already good
  r = '󰟔 ', -- already good
  cs = '󰌛 ', -- C# (already good)
  zig = ' ', -- Zig
  dart = ' ', -- Dart / Flutter
  git = '󰊢 ', -- already good
  gitconfig = '󰊢 ', -- already good (same as git)
}

local DEFAULT_ICON = '󰈚 '

local function fmt_size(bytes)
  if bytes <= 0 then
    return '0B'
  end
  local units, i, s = { 'B', 'K', 'M', 'G' }, 1, bytes
  while s >= 1024 and i < #units do
    s = s / 1024
    i = i + 1
  end
  return i == 1 and string.format('%dB', s) or string.format('%.1f%s', s, units[i])
end

local function smart_path(name, max_w)
  if name == '' then
    return '[No Name]'
  end
  local rel = vim.fn.fnamemodify(name, ':~:.')
  if #rel <= max_w then
    return rel
  end
  local parts = vim.split(rel, '/', { plain = true })
  for i = 2, #parts do
    local c = '…/' .. table.concat(parts, '/', i)
    if #c <= max_w then
      return c
    end
  end
  return '…/' .. parts[#parts]
end

-- ---------------------------------------------------------------------------
-- Build the rendered string (called once per cache miss)
-- ---------------------------------------------------------------------------
local function build(winid, bufnr, active)
  local win_width = vim.api.nvim_win_get_width(winid)
  local very_compact = win_width < 55
  local compact = win_width < 80

  local ft = vim.bo[bufnr].filetype or ''
  local icon = ft_icons[ft:lower()] or DEFAULT_ICON
  local name = vim.api.nvim_buf_get_name(bufnr)

  local icon_str = hl 'StatusLineFileIcon' .. icon .. hl 'StatusLine'

  local path_max = very_compact and 15 or compact and 25 or math.floor(win_width * 0.30)
  local path_str = hl 'StatusLineFilePath' .. smart_path(name, path_max) .. hl 'StatusLine'

  local mod_str = vim.bo[bufnr].modified and (hl 'StatusLineModified' .. ' ●' .. hl 'StatusLine') or ''
  local ro_str = (vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable) and (hl 'StatusLineReadonly' .. '  ' .. hl 'StatusLine') or ''

  local bufnr_str = hl 'StatusLineBufNr' .. '[' .. bufnr .. ']' .. hl 'StatusLine'

  if very_compact then
    return ' ' .. icon_str .. path_str .. mod_str .. ro_str .. ' '
  end

  local size_bytes = vim.fn.getfsize(name)
  local size_str = hl 'StatusLineFileSize' .. fmt_size(math.max(0, size_bytes)) .. hl 'StatusLine'

  if compact then
    return ' ' .. bufnr_str .. ' ' .. icon_str .. path_str .. mod_str .. ro_str .. '  ' .. size_str .. ' '
  end

  local lines_str = hl 'StatusLineLineCount' .. '󰦕 ' .. vim.api.nvim_buf_line_count(bufnr) .. 'L' .. hl 'StatusLine'

  local enc = (vim.bo[bufnr].fileencoding ~= '' and vim.bo[bufnr].fileencoding) or vim.o.encoding or 'utf-8'
  local ff = vim.bo[bufnr].fileformat
  local ff_label = ff == 'unix' and 'LF' or ff == 'dos' and 'CRLF' or 'CR'

  local enc_str = hl 'StatusLineEncoding' .. enc:upper() .. hl 'StatusLine'
  local ff_str = hl 'StatusLineEncoding' .. ff_label .. hl 'StatusLine'
  local ft_str = ft ~= '' and (' ' .. hl 'StatusLineFilePath' .. ft .. hl 'StatusLine') or ''

  return ' '
    .. bufnr_str
    .. ' '
    .. icon_str
    .. path_str
    .. mod_str
    .. ro_str
    .. '  '
    .. size_str
    .. '  '
    .. lines_str
    .. ft_str
    .. '  '
    .. enc_str
    .. ' '
    .. ff_str
    .. ' '
end

-- ---------------------------------------------------------------------------
-- Public render (hot path: one table lookup, or build+cache on miss)
-- ---------------------------------------------------------------------------
function M.render(winid, bufnr, active)
  local key = cache_key(bufnr, winid)
  if _cache[key] then
    return _cache[key]
  end
  local s = build(winid, bufnr, active)
  _cache[key] = s
  return s
end

return M
