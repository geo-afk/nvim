-- explorer/icons.lua

local cfg = require 'custom.explorer.config'

local M = {}

-- ── Built-in extension → Nerd Font v3 glyph ───────────────────────────────

local EXT = {
  lua = '󰢱',
  py = '󰌠',
  rb = '󰴭',
  js = '󰌞',
  ts = '󰛦',
  jsx = '󰌞',
  tsx = '󰛦',
  sh = '󰒓',
  bash = '󰒓',
  zsh = '󰒓',
  fish = '󰒓',
  ps1 = '󰒓',
  vim = '',
  nvim = '',
  json = '󰘦',
  jsonc = '󰘦',
  yaml = '󰘦',
  yml = '󰘦',
  toml = '󰘦',
  ini = '󰘦',
  cfg = '󰘦',
  env = '',
  html = '󰌝',
  htm = '󰌝',
  xml = '󰗀',
  svg = '󰜡',
  css = '󰌜',
  scss = '󰌜',
  less = '󰌜',
  md = '󰍔',
  mdx = '󰍔',
  rst = '󰗚',
  tex = '󰙩',
  txt = '󰈙',
  c = '󰙱',
  h = '󰙱',
  cpp = '󰙲',
  hpp = '󰙲',
  cs = '󰌛',
  rs = '󰈸',
  go = '󰟓',
  java = '󰬷',
  kt = '󰬱',
  swift = '󰛄',
  dart = '󰈜',
  sql = '󰆼',
  db = '󰆼',
  sqlite = '󰆼',
  csv = '󰈙',
  tsv = '󰈙',
  png = '󰈟',
  jpg = '󰈟',
  jpeg = '󰈟',
  gif = '󰈟',
  bmp = '󰈟',
  ico = '󰈟',
  webp = '󰈟',
  mp4 = '󰈫',
  mov = '󰈫',
  mkv = '󰈫',
  avi = '󰈫',
  mp3 = '󰈣',
  wav = '󰈣',
  flac = '󰈣',
  zip = '󰗄',
  tar = '󰗄',
  gz = '󰗄',
  bz2 = '󰗄',
  xz = '󰗄',
  rar = '󰗄',
  ['7z'] = '󰗄',
  pdf = '󰈦',
  lock = '󰌾',
  log = '󰱻',
  diff = '',
  patch = '',
  dockerfile = '󰡨',
  makefile = '󱁤',
  gitignore = '󰊢',
  gitattributes = '󰊢',
}
local NAMES = {
  ['.gitignore'] = '󰊢',
  ['.gitattributes'] = '󰊢',
  ['.gitmodules'] = '󰊢',
  ['makefile'] = '󱁤',
  ['dockerfile'] = '󰡨',
  ['docker-compose.yml'] = '󰡨',
  ['readme.md'] = '󰍔',
  ['license'] = '󰿃',
  ['.env'] = '',
  ['.env.local'] = '',
  ['.env.example'] = '',
  ['package.json'] = '󰎙',
  ['package-lock.json'] = '󰎙',
  ['cargo.toml'] = '󰈸',
  ['cargo.lock'] = '󰈸',
  ['go.mod'] = '󰟓',
  ['go.sum'] = '󰟓',
}

M.DIR_OPEN = '󰝰'
M.DIR_CLOSED = '󰉋'
M.SYMLINK = '󰉒'
M.FILE_DEF = '󰈙'

-- ── Provider implementations ─────────────────────────────────────────────

local function builtin(path, is_dir)
  if is_dir then
    return M.DIR_CLOSED, 'Directory'
  end
  local uv = vim.uv or vim.loop
  local ls = uv.fs_lstat(path)
  if ls and ls.type == 'link' then
    return M.SYMLINK, 'Comment'
  end
  local name = vim.fn.fnamemodify(path, ':t'):lower()
  local ext = name:match '%.([^.]+)$' or ''
  return (NAMES[name] or EXT[ext] or M.FILE_DEF), nil
end

local function none(_, is_dir)
  return is_dir and '▶' or ' ', nil
end

local function mini(path, is_dir)
  local ok, icon, hl
  if is_dir then
    ok, icon, hl = pcall(MiniIcons.get, 'directory', path) --luacheck:ignore
  else
    ok, icon, hl = pcall(MiniIcons.get, 'file', path) --luacheck:ignore
  end
  if ok and icon then
    return icon, hl
  end
  return builtin(path, is_dir)
end

local function devicons(path, is_dir)
  if is_dir then
    return M.DIR_CLOSED, 'Directory'
  end
  local dv = package.loaded['nvim-web-devicons']
  if dv then
    local icon, hl = dv.get_icon(vim.fn.fnamemodify(path, ':t'), vim.fn.fnamemodify(path, ':e'), { default = true })
    if icon then
      return icon, hl
    end
  end
  return builtin(path, is_dir)
end

-- ── Public resolver ───────────────────────────────────────────────────────

function M.resolve()
  local style = cfg.get().icons.style
  if style == 'none' then
    return none
  end
  if style == 'mini' then
    return mini
  end
  if style == 'devicons' then
    return devicons
  end
  -- "auto" or "builtin"
  if _G.MiniIcons then
    return mini
  end
  if package.loaded['nvim-web-devicons'] then
    return devicons
  end
  return builtin
end

return M
