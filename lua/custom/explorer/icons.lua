-- custom/explorer/icons.lua

local cfg = require("custom.explorer.config")

local M = {}

-- File extension icons
local EXT = {
  -- scripting / config
  lua = "",
  vim = "",
  sh = "",
  bash = "",
  zsh = "",
  fish = "",
  ps1 = "󰨊",

  -- web
  html = "",
  css = "",
  scss = "",
  less = "",
  js = "",
  ts = "󰛦",
  jsx = "",
  tsx = "",
  json = "",
  jsonc = "",

  -- backend / compiled
  c = "",
  h = "",
  cpp = "",
  hpp = "",
  cs = "󰌛",
  java = "",
  go = "",
  rs = "",
  swift = "",
  kt = "󱈙",

  -- scripting langs
  py = "",
  rb = "",
  php = "",

  -- data / config
  yaml = "",
  yml = "",
  toml = "",
  ini = "",
  cfg = "",

  -- docs
  md = "",
  txt = "",
  rst = "",
  tex = "󰙩",

  -- images
  png = "󰉏",
  jpg = "󰉏",
  jpeg = "󰉏",
  gif = "󰉏",
  svg = "󰜡",
  webp = "󰉏",
  ico = "󰉏",

  -- media
  mp4 = "󰈫",
  mkv = "󰈫",
  mov = "󰈫",
  avi = "󰈫",
  mp3 = "󰈣",
  wav = "󰈣",
  flac = "󰈣",

  -- archives
  zip = "󰗄",
  tar = "󰗄",
  gz = "󰗄",
  bz2 = "󰗄",
  xz = "󰗄",
  rar = "󰗄",
  ["7z"] = "󰗄",

  -- misc
  sql = "󰆼",
  db = "󰆼",
  sqlite = "󰆼",
  log = "󰌱",
  lock = "󰌾",
  diff = "",
  patch = "",
}

-- Exact filename matches
local NAMES = {
  [".gitignore"] = "",
  [".gitattributes"] = "",
  [".gitmodules"] = "",

  ["makefile"] = "",
  ["cmakelists.txt"] = "",

  ["dockerfile"] = "󰡨",
  ["docker-compose.yml"] = "󰡨",

  ["package.json"] = "",
  ["package-lock.json"] = "",
  ["yarn.lock"] = "",
  ["pnpm-lock.yaml"] = "",

  ["readme.md"] = "",
  ["license"] = "󰿃",

  [".env"] = "󰒓",
  [".env.local"] = "󰒓",
  [".env.example"] = "󰒓",

  ["go.mod"] = "",
  ["go.sum"] = "",

  ["cargo.toml"] = "",
  ["cargo.lock"] = "",
}

-- Core icons
M.DIR_OPEN = "󰝰"
M.DIR_CLOSED = "󰉋"
M.SYMLINK = "󰉒"
M.FILE_DEF = ""

-- Built-in resolver (ONLY resolver now)
local function builtin(path, is_dir)
  if is_dir then
    return M.DIR_CLOSED, "ExplorerDirectory"
  end

  local uv = vim.uv or vim.loop
  local stat = uv.fs_lstat(path)

  if stat and stat.type == "link" then
    return M.SYMLINK, "Comment"
  end

  local name = vim.fn.fnamemodify(path, ":t"):lower()
  local ext = name:match("%.([^.]+)$") or ""

  return (NAMES[name] or EXT[ext] or M.FILE_DEF), nil
end

-- Minimal mode (no icons)
local function none(_, is_dir)
  return is_dir and "▶" or " ", nil
end

-- Public resolver
function M.resolve()
  local style = cfg.get().icons.style

  if style == "none" then
    return none
  end

  -- default: always builtin (no deps anymore)
  return builtin
end

return M
