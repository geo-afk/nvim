-- custom/explorer/icons.lua

local cfg = require("custom.explorer.config")

local M = {}

local GROUPS = {
  "ExplorerIconDir",
  "ExplorerIconDirOpen",
  "ExplorerIconLink",
  "ExplorerIconDefault",
  "ExplorerIconLua",
  "ExplorerIconVim",
  "ExplorerIconShell",
  "ExplorerIconPowerShell",
  "ExplorerIconWeb",
  "ExplorerIconTypeScript",
  "ExplorerIconData",
  "ExplorerIconCompiled",
  "ExplorerIconDotnet",
  "ExplorerIconJava",
  "ExplorerIconGo",
  "ExplorerIconRust",
  "ExplorerIconPython",
  "ExplorerIconRuby",
  "ExplorerIconPhp",
  "ExplorerIconDocs",
  "ExplorerIconImage",
  "ExplorerIconMedia",
  "ExplorerIconArchive",
  "ExplorerIconDatabase",
  "ExplorerIconLog",
  "ExplorerIconLock",
  "ExplorerIconGit",
  "ExplorerIconDocker",
  "ExplorerIconPackage",
  "ExplorerIconEnv",
  "ExplorerIconBuild",
}

M.GROUPS = GROUPS

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

local EXT_HL = {
  lua = "ExplorerIconLua",
  vim = "ExplorerIconVim",
  sh = "ExplorerIconShell",
  bash = "ExplorerIconShell",
  zsh = "ExplorerIconShell",
  fish = "ExplorerIconShell",
  ps1 = "ExplorerIconPowerShell",
  html = "ExplorerIconWeb",
  css = "ExplorerIconWeb",
  scss = "ExplorerIconWeb",
  less = "ExplorerIconWeb",
  js = "ExplorerIconWeb",
  ts = "ExplorerIconTypeScript",
  jsx = "ExplorerIconWeb",
  tsx = "ExplorerIconTypeScript",
  json = "ExplorerIconData",
  jsonc = "ExplorerIconData",
  c = "ExplorerIconCompiled",
  h = "ExplorerIconCompiled",
  cpp = "ExplorerIconCompiled",
  hpp = "ExplorerIconCompiled",
  cs = "ExplorerIconDotnet",
  java = "ExplorerIconJava",
  go = "ExplorerIconGo",
  rs = "ExplorerIconRust",
  swift = "ExplorerIconCompiled",
  kt = "ExplorerIconCompiled",
  py = "ExplorerIconPython",
  rb = "ExplorerIconRuby",
  php = "ExplorerIconPhp",
  yaml = "ExplorerIconData",
  yml = "ExplorerIconData",
  toml = "ExplorerIconData",
  ini = "ExplorerIconData",
  cfg = "ExplorerIconData",
  md = "ExplorerIconDocs",
  txt = "ExplorerIconDocs",
  rst = "ExplorerIconDocs",
  tex = "ExplorerIconDocs",
  png = "ExplorerIconImage",
  jpg = "ExplorerIconImage",
  jpeg = "ExplorerIconImage",
  gif = "ExplorerIconImage",
  svg = "ExplorerIconImage",
  webp = "ExplorerIconImage",
  ico = "ExplorerIconImage",
  mp4 = "ExplorerIconMedia",
  mkv = "ExplorerIconMedia",
  mov = "ExplorerIconMedia",
  avi = "ExplorerIconMedia",
  mp3 = "ExplorerIconMedia",
  wav = "ExplorerIconMedia",
  flac = "ExplorerIconMedia",
  zip = "ExplorerIconArchive",
  tar = "ExplorerIconArchive",
  gz = "ExplorerIconArchive",
  bz2 = "ExplorerIconArchive",
  xz = "ExplorerIconArchive",
  rar = "ExplorerIconArchive",
  ["7z"] = "ExplorerIconArchive",
  sql = "ExplorerIconDatabase",
  db = "ExplorerIconDatabase",
  sqlite = "ExplorerIconDatabase",
  log = "ExplorerIconLog",
  lock = "ExplorerIconLock",
  diff = "ExplorerIconGit",
  patch = "ExplorerIconGit",
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

local NAME_HL = {
  [".gitignore"] = "ExplorerIconGit",
  [".gitattributes"] = "ExplorerIconGit",
  [".gitmodules"] = "ExplorerIconGit",
  ["makefile"] = "ExplorerIconBuild",
  ["cmakelists.txt"] = "ExplorerIconBuild",
  ["dockerfile"] = "ExplorerIconDocker",
  ["docker-compose.yml"] = "ExplorerIconDocker",
  ["package.json"] = "ExplorerIconPackage",
  ["package-lock.json"] = "ExplorerIconPackage",
  ["yarn.lock"] = "ExplorerIconPackage",
  ["pnpm-lock.yaml"] = "ExplorerIconPackage",
  ["readme.md"] = "ExplorerIconDocs",
  ["license"] = "ExplorerIconDocs",
  [".env"] = "ExplorerIconEnv",
  [".env.local"] = "ExplorerIconEnv",
  [".env.example"] = "ExplorerIconEnv",
  ["go.mod"] = "ExplorerIconGo",
  ["go.sum"] = "ExplorerIconGo",
  ["cargo.toml"] = "ExplorerIconRust",
  ["cargo.lock"] = "ExplorerIconRust",
}

-- Core icons
M.DIR_OPEN = "󰝰"
M.DIR_CLOSED = "󰉋"
M.SYMLINK = "󰉒"
M.FILE_DEF = ""

-- Built-in resolver (ONLY resolver now)
local function builtin(path, is_dir, is_link)
  if is_dir then
    return M.DIR_CLOSED, "ExplorerIconDir"
  end

  if is_link then
    return M.SYMLINK, "ExplorerIconLink"
  end

  local name = vim.fn.fnamemodify(path, ":t"):lower()
  local ext = name:match("%.([^.]+)$") or ""

  return (NAMES[name] or EXT[ext] or M.FILE_DEF), (NAME_HL[name] or EXT_HL[ext] or "ExplorerIconDefault")
end

-- Minimal mode (no icons)
local function none(_, is_dir)
  return is_dir and "▶" or " ", is_dir and "ExplorerIconDir" or "ExplorerIconDefault"
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
