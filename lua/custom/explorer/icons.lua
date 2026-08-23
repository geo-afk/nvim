-- custom/explorer/icons.lua

local cfg = require("custom.explorer.config")

local M = {}

local GROUPS = {
  "ExplorerIconDir",
  "ExplorerIconDirOpen",
  "ExplorerIconLink",
  "ExplorerIconDefault",

  -- languages
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
  "ExplorerIconDart",
  "ExplorerIconElixir",
  "ExplorerIconErlang",
  "ExplorerIconHaskell",
  "ExplorerIconScala",
  "ExplorerIconKotlin",
  "ExplorerIconSwift",
  "ExplorerIconR",
  "ExplorerIconJulia",
  "ExplorerIconPerl",
  "ExplorerIconClojure",
  "ExplorerIconZig",
  "ExplorerIconNix",
  "ExplorerIconSolidity",

  -- frameworks / ecosystems
  "ExplorerIconAngular",
  "ExplorerIconReact",
  "ExplorerIconVue",
  "ExplorerIconSvelte",
  "ExplorerIconNode",
  "ExplorerIconPackage",
  "ExplorerIconDocker",
  "ExplorerIconKubernetes",
  "ExplorerIconTerraform",

  -- content
  "ExplorerIconDocs",
  "ExplorerIconImage",
  "ExplorerIconMedia",
  "ExplorerIconFont",
  "ExplorerIconArchive",
  "ExplorerIconDatabase",
  "ExplorerIconLog",
  "ExplorerIconLock",

  -- tooling
  "ExplorerIconGit",
  "ExplorerIconGitHub",
  "ExplorerIconGitLab",
  "ExplorerIconEnv",
  "ExplorerIconBuild",
  "ExplorerIconConfig",
  "ExplorerIconTest",
  "ExplorerIconLint",
  "ExplorerIconCI",
}

M.GROUPS = GROUPS

-- ============================================================================
-- File extension icons
-- ============================================================================

local EXT = {
  -- Lua / Vim
  lua = "",
  vim = "",

  -- Shell
  sh = "",
  bash = "",
  zsh = "",
  fish = "",
  ksh = "",
  csh = "",
  tcsh = "",

  -- PowerShell
  ps1 = "󰨊",
  psm1 = "󰨊",
  psd1 = "󰨊",

  -- HTML / XML
  html = "",
  htm = "",
  xhtml = "",
  xml = "󰗀",
  xsd = "󰗀",
  xsl = "󰗀",
  xslt = "󰗀",

  -- CSS
  css = "",
  scss = "",
  sass = "",
  less = "",
  styl = "",

  -- JavaScript / Node
  js = "",
  mjs = "",
  cjs = "",

  -- TypeScript
  ts = "󰛦",
  mts = "󰛦",
  cts = "󰛦",

  -- React
  jsx = "",
  tsx = "",

  -- Angular
  component = "",

  -- Vue
  vue = "",

  -- Svelte
  svelte = "",

  -- Astro
  astro = "",

  -- JSON
  json = "",
  jsonc = "",
  json5 = "",
  jsonl = "",

  -- YAML
  yaml = "",
  yml = "",

  -- TOML / config
  toml = "",
  ini = "",
  cfg = "",
  conf = "",
  config = "",
  properties = "",

  -- C
  c = "",
  h = "",

  -- C++
  cc = "",
  cpp = "",
  cxx = "",
  hpp = "",
  hxx = "",
  hh = "",

  -- Objective-C
  m = "",
  mm = "",

  -- C#
  cs = "󰌛",
  csx = "󰌛",

  -- F#
  fs = "",
  fsx = "",
  fsi = "",

  -- Visual Basic
  vb = "󰛤",

  -- Java / JVM
  java = "",
  class = "",
  jar = "",

  -- Kotlin
  kt = "󱈙",
  kts = "󱈙",

  -- Scala
  scala = "",
  sc = "",

  -- Groovy
  groovy = "",
  gradle = "",

  -- Go
  go = "",

  -- Rust
  rs = "",

  -- Zig
  zig = "",

  -- Swift
  swift = "",

  -- Dart / Flutter
  dart = "",

  -- Python
  py = "",
  pyw = "",
  pyx = "",
  pyi = "",
  pyc = "",

  -- Ruby
  rb = "",
  erb = "",
  rake = "",
  gemspec = "",

  -- PHP
  php = "",
  phtml = "",

  -- Perl
  pl = "",
  pm = "",

  -- R
  r = "󰟔",
  rmd = "󰟔",

  -- Julia
  jl = "",

  -- Elixir
  ex = "",
  exs = "",
  eex = "",
  heex = "",
  leex = "",

  -- Erlang
  erl = "",
  hrl = "",

  -- Haskell
  hs = "",
  lhs = "",

  -- Clojure
  clj = "",
  cljs = "",
  cljc = "",
  edn = "",

  -- Lisp / Scheme
  lisp = "󰘧",
  el = "",
  scm = "󰘧",
  ss = "󰘧",
  rkt = "󰘧",

  -- OCaml
  ml = "",
  mli = "",

  -- Nim
  nim = "",

  -- Crystal
  cr = "",

  -- Solidity
  sol = "",

  -- Nix
  nix = "",

  -- Terraform / HCL
  tf = "󱁢",
  tfvars = "󱁢",
  hcl = "󱁢",

  -- SQL / database
  sql = "󰆼",
  mysql = "",
  pgsql = "",
  db = "󰆼",
  sqlite = "",
  sqlite3 = "",
  db3 = "󰆼",
  mdb = "󰆼",

  -- GraphQL
  graphql = "󰡷",
  gql = "󰡷",

  -- Protocol buffers
  proto = "",

  -- Prisma
  prisma = "",

  -- Markdown / docs
  md = "",
  markdown = "",
  mdx = "",
  txt = "",
  text = "",
  rst = "",
  adoc = "",
  asciidoc = "",
  tex = "󰙩",
  latex = "󰙩",
  bib = "󱉟",
  org = "",

  -- CSV / tabular
  csv = "",
  tsv = "",
  xls = "󰈛",
  xlsx = "󰈛",
  ods = "󰈛",

  -- Documents
  pdf = "",
  doc = "󰈬",
  docx = "󰈬",
  odt = "󰈬",
  ppt = "󰈧",
  pptx = "󰈧",
  odp = "󰈧",

  -- Images
  png = "󰉏",
  jpg = "󰉏",
  jpeg = "󰉏",
  jpe = "󰉏",
  gif = "󰉏",
  bmp = "󰉏",
  webp = "󰉏",
  avif = "󰉏",
  tif = "󰉏",
  tiff = "󰉏",
  ico = "",
  svg = "󰜡",
  svgz = "󰜡",
  psd = "",
  ai = "",

  -- Video
  mp4 = "󰈫",
  mkv = "󰈫",
  mov = "󰈫",
  avi = "󰈫",
  webm = "󰈫",
  m4v = "󰈫",
  flv = "󰈫",
  wmv = "󰈫",
  mpg = "󰈫",
  mpeg = "󰈫",

  -- Audio
  mp3 = "󰈣",
  wav = "󰈣",
  flac = "󰈣",
  m4a = "󰈣",
  aac = "󰈣",
  ogg = "󰈣",
  opus = "󰈣",
  wma = "󰈣",
  mid = "󰎆",
  midi = "󰎆",

  -- Fonts
  ttf = "",
  otf = "",
  woff = "",
  woff2 = "",
  eot = "",

  -- Archives / compression
  zip = "󰗄",
  tar = "󰗄",
  gz = "󰗄",
  gzip = "󰗄",
  bz = "󰗄",
  bz2 = "󰗄",
  xz = "󰗄",
  rar = "󰗄",
  ["7z"] = "󰗄",
  tgz = "󰗄",
  tbz = "󰗄",
  tbz2 = "󰗄",
  txz = "󰗄",
  zst = "󰗄",
  lz = "󰗄",
  lz4 = "󰗄",

  -- Executables / binaries
  exe = "",
  dll = "",
  so = "",
  dylib = "",
  bin = "",
  app = "",
  apk = "",
  ipa = "",
  wasm = "",

  -- Object / compiled files
  o = "",
  obj = "",
  a = "",
  lib = "",

  -- Logs
  log = "󰌱",

  -- Lock files
  lock = "󰌾",

  -- Git
  diff = "",
  patch = "",

  -- Certificates / crypto
  pem = "󰌆",
  crt = "󰌆",
  cer = "󰌆",
  key = "󰌆",
  pub = "󰷖",
  p12 = "󰌆",
  pfx = "󰌆",

  -- SSH
  authorized_keys = "󰌆",

  -- Docker
  dockerfile = "󰡨",

  -- Kubernetes
  helm = "󰠳",

  -- HTTP / REST
  http = "󰖟",
  rest = "󰖟",

  -- OpenAPI
  swagger = "󰖟",

  -- templating
  mustache = "",
  hbs = "",
  handlebars = "",
  ejs = "",
  pug = "",
  jade = "",
  njk = "",
  jinja = "",
  jinja2 = "",
  twig = "",

  -- testing / snapshots
  snap = "󰙨",

  -- misc
  bak = "󰁯",
  tmp = "󰪺",
  temp = "󰪺",
  cache = "󰃨",
}

-- ============================================================================
-- Extension highlight groups
-- ============================================================================

local EXT_HL = {
  -- Lua / Vim
  lua = "ExplorerIconLua",
  vim = "ExplorerIconVim",

  -- shells
  sh = "ExplorerIconShell",
  bash = "ExplorerIconShell",
  zsh = "ExplorerIconShell",
  fish = "ExplorerIconShell",
  ksh = "ExplorerIconShell",
  csh = "ExplorerIconShell",
  tcsh = "ExplorerIconShell",

  -- powershell
  ps1 = "ExplorerIconPowerShell",
  psm1 = "ExplorerIconPowerShell",
  psd1 = "ExplorerIconPowerShell",

  -- web
  html = "ExplorerIconWeb",
  htm = "ExplorerIconWeb",
  xhtml = "ExplorerIconWeb",
  xml = "ExplorerIconData",
  xsd = "ExplorerIconData",
  xsl = "ExplorerIconData",
  xslt = "ExplorerIconData",

  css = "ExplorerIconWeb",
  scss = "ExplorerIconWeb",
  sass = "ExplorerIconWeb",
  less = "ExplorerIconWeb",
  styl = "ExplorerIconWeb",

  js = "ExplorerIconWeb",
  mjs = "ExplorerIconWeb",
  cjs = "ExplorerIconWeb",
  jsx = "ExplorerIconReact",

  ts = "ExplorerIconTypeScript",
  mts = "ExplorerIconTypeScript",
  cts = "ExplorerIconTypeScript",
  tsx = "ExplorerIconReact",

  vue = "ExplorerIconVue",
  svelte = "ExplorerIconSvelte",
  astro = "ExplorerIconWeb",

  -- data/config
  json = "ExplorerIconData",
  jsonc = "ExplorerIconData",
  json5 = "ExplorerIconData",
  jsonl = "ExplorerIconData",
  yaml = "ExplorerIconData",
  yml = "ExplorerIconData",
  toml = "ExplorerIconData",
  ini = "ExplorerIconConfig",
  cfg = "ExplorerIconConfig",
  conf = "ExplorerIconConfig",
  config = "ExplorerIconConfig",
  properties = "ExplorerIconConfig",

  -- C/C++
  c = "ExplorerIconCompiled",
  h = "ExplorerIconCompiled",
  cc = "ExplorerIconCompiled",
  cpp = "ExplorerIconCompiled",
  cxx = "ExplorerIconCompiled",
  hpp = "ExplorerIconCompiled",
  hxx = "ExplorerIconCompiled",
  hh = "ExplorerIconCompiled",
  m = "ExplorerIconCompiled",
  mm = "ExplorerIconCompiled",

  -- dotnet
  cs = "ExplorerIconDotnet",
  csx = "ExplorerIconDotnet",
  fs = "ExplorerIconDotnet",
  fsx = "ExplorerIconDotnet",
  fsi = "ExplorerIconDotnet",
  vb = "ExplorerIconDotnet",

  -- JVM
  java = "ExplorerIconJava",
  class = "ExplorerIconJava",
  jar = "ExplorerIconJava",
  kt = "ExplorerIconKotlin",
  kts = "ExplorerIconKotlin",
  scala = "ExplorerIconScala",
  sc = "ExplorerIconScala",
  groovy = "ExplorerIconJava",
  gradle = "ExplorerIconBuild",

  go = "ExplorerIconGo",
  rs = "ExplorerIconRust",
  zig = "ExplorerIconZig",
  swift = "ExplorerIconSwift",
  dart = "ExplorerIconDart",

  py = "ExplorerIconPython",
  pyw = "ExplorerIconPython",
  pyx = "ExplorerIconPython",
  pyi = "ExplorerIconPython",
  pyc = "ExplorerIconPython",

  rb = "ExplorerIconRuby",
  erb = "ExplorerIconRuby",
  rake = "ExplorerIconRuby",
  gemspec = "ExplorerIconRuby",

  php = "ExplorerIconPhp",
  phtml = "ExplorerIconPhp",

  pl = "ExplorerIconPerl",
  pm = "ExplorerIconPerl",

  r = "ExplorerIconR",
  rmd = "ExplorerIconR",

  jl = "ExplorerIconJulia",

  ex = "ExplorerIconElixir",
  exs = "ExplorerIconElixir",
  eex = "ExplorerIconElixir",
  heex = "ExplorerIconElixir",
  leex = "ExplorerIconElixir",

  erl = "ExplorerIconErlang",
  hrl = "ExplorerIconErlang",

  hs = "ExplorerIconHaskell",
  lhs = "ExplorerIconHaskell",

  clj = "ExplorerIconClojure",
  cljs = "ExplorerIconClojure",
  cljc = "ExplorerIconClojure",
  edn = "ExplorerIconClojure",

  lisp = "ExplorerIconCompiled",
  el = "ExplorerIconCompiled",
  scm = "ExplorerIconCompiled",
  ss = "ExplorerIconCompiled",
  rkt = "ExplorerIconCompiled",

  ml = "ExplorerIconCompiled",
  mli = "ExplorerIconCompiled",
  nim = "ExplorerIconCompiled",
  cr = "ExplorerIconCompiled",

  sol = "ExplorerIconSolidity",
  nix = "ExplorerIconNix",

  -- infra
  tf = "ExplorerIconTerraform",
  tfvars = "ExplorerIconTerraform",
  hcl = "ExplorerIconTerraform",

  -- database
  sql = "ExplorerIconDatabase",
  mysql = "ExplorerIconDatabase",
  pgsql = "ExplorerIconDatabase",
  db = "ExplorerIconDatabase",
  sqlite = "ExplorerIconDatabase",
  sqlite3 = "ExplorerIconDatabase",
  db3 = "ExplorerIconDatabase",
  mdb = "ExplorerIconDatabase",

  graphql = "ExplorerIconData",
  gql = "ExplorerIconData",
  proto = "ExplorerIconData",
  prisma = "ExplorerIconDatabase",

  -- docs
  md = "ExplorerIconDocs",
  markdown = "ExplorerIconDocs",
  mdx = "ExplorerIconDocs",
  txt = "ExplorerIconDocs",
  text = "ExplorerIconDocs",
  rst = "ExplorerIconDocs",
  adoc = "ExplorerIconDocs",
  asciidoc = "ExplorerIconDocs",
  tex = "ExplorerIconDocs",
  latex = "ExplorerIconDocs",
  bib = "ExplorerIconDocs",
  org = "ExplorerIconDocs",

  csv = "ExplorerIconData",
  tsv = "ExplorerIconData",
  xls = "ExplorerIconData",
  xlsx = "ExplorerIconData",
  ods = "ExplorerIconData",

  pdf = "ExplorerIconDocs",
  doc = "ExplorerIconDocs",
  docx = "ExplorerIconDocs",
  odt = "ExplorerIconDocs",
  ppt = "ExplorerIconDocs",
  pptx = "ExplorerIconDocs",
  odp = "ExplorerIconDocs",

  -- images
  png = "ExplorerIconImage",
  jpg = "ExplorerIconImage",
  jpeg = "ExplorerIconImage",
  jpe = "ExplorerIconImage",
  gif = "ExplorerIconImage",
  bmp = "ExplorerIconImage",
  webp = "ExplorerIconImage",
  avif = "ExplorerIconImage",
  tif = "ExplorerIconImage",
  tiff = "ExplorerIconImage",
  ico = "ExplorerIconImage",
  svg = "ExplorerIconImage",
  svgz = "ExplorerIconImage",
  psd = "ExplorerIconImage",
  ai = "ExplorerIconImage",

  -- media
  mp4 = "ExplorerIconMedia",
  mkv = "ExplorerIconMedia",
  mov = "ExplorerIconMedia",
  avi = "ExplorerIconMedia",
  webm = "ExplorerIconMedia",
  m4v = "ExplorerIconMedia",
  flv = "ExplorerIconMedia",
  wmv = "ExplorerIconMedia",
  mpg = "ExplorerIconMedia",
  mpeg = "ExplorerIconMedia",

  mp3 = "ExplorerIconMedia",
  wav = "ExplorerIconMedia",
  flac = "ExplorerIconMedia",
  m4a = "ExplorerIconMedia",
  aac = "ExplorerIconMedia",
  ogg = "ExplorerIconMedia",
  opus = "ExplorerIconMedia",
  wma = "ExplorerIconMedia",
  mid = "ExplorerIconMedia",
  midi = "ExplorerIconMedia",

  -- font
  ttf = "ExplorerIconFont",
  otf = "ExplorerIconFont",
  woff = "ExplorerIconFont",
  woff2 = "ExplorerIconFont",
  eot = "ExplorerIconFont",

  -- archive
  zip = "ExplorerIconArchive",
  tar = "ExplorerIconArchive",
  gz = "ExplorerIconArchive",
  gzip = "ExplorerIconArchive",
  bz = "ExplorerIconArchive",
  bz2 = "ExplorerIconArchive",
  xz = "ExplorerIconArchive",
  rar = "ExplorerIconArchive",
  ["7z"] = "ExplorerIconArchive",
  tgz = "ExplorerIconArchive",
  tbz = "ExplorerIconArchive",
  tbz2 = "ExplorerIconArchive",
  txz = "ExplorerIconArchive",
  zst = "ExplorerIconArchive",
  lz = "ExplorerIconArchive",
  lz4 = "ExplorerIconArchive",

  -- compiled/binary
  exe = "ExplorerIconCompiled",
  dll = "ExplorerIconCompiled",
  so = "ExplorerIconCompiled",
  dylib = "ExplorerIconCompiled",
  bin = "ExplorerIconCompiled",
  app = "ExplorerIconCompiled",
  apk = "ExplorerIconCompiled",
  ipa = "ExplorerIconCompiled",
  wasm = "ExplorerIconCompiled",
  o = "ExplorerIconCompiled",
  obj = "ExplorerIconCompiled",
  a = "ExplorerIconCompiled",
  lib = "ExplorerIconCompiled",

  log = "ExplorerIconLog",
  lock = "ExplorerIconLock",

  diff = "ExplorerIconGit",
  patch = "ExplorerIconGit",

  -- crypto
  pem = "ExplorerIconLock",
  crt = "ExplorerIconLock",
  cer = "ExplorerIconLock",
  key = "ExplorerIconLock",
  pub = "ExplorerIconLock",
  p12 = "ExplorerIconLock",
  pfx = "ExplorerIconLock",

  dockerfile = "ExplorerIconDocker",
  helm = "ExplorerIconKubernetes",

  http = "ExplorerIconWeb",
  rest = "ExplorerIconWeb",
  swagger = "ExplorerIconWeb",

  -- templates
  mustache = "ExplorerIconWeb",
  hbs = "ExplorerIconWeb",
  handlebars = "ExplorerIconWeb",
  ejs = "ExplorerIconWeb",
  pug = "ExplorerIconWeb",
  jade = "ExplorerIconWeb",
  njk = "ExplorerIconWeb",
  jinja = "ExplorerIconWeb",
  jinja2 = "ExplorerIconWeb",
  twig = "ExplorerIconWeb",

  snap = "ExplorerIconTest",

  bak = "ExplorerIconDefault",
  tmp = "ExplorerIconDefault",
  temp = "ExplorerIconDefault",
  cache = "ExplorerIconDefault",
}

-- ============================================================================
-- Exact filename matches
-- ============================================================================

local NAMES = {
  -- --------------------------------------------------------------------------
  -- Git
  -- --------------------------------------------------------------------------

  [".gitignore"] = "",
  [".gitattributes"] = "",
  [".gitmodules"] = "",
  [".gitkeep"] = "",
  [".gitconfig"] = "",
  [".mailmap"] = "",

  -- --------------------------------------------------------------------------
  -- GitHub
  -- --------------------------------------------------------------------------

  ["codeowners"] = "",
  ["dependabot.yml"] = "",
  ["dependabot.yaml"] = "",

  -- --------------------------------------------------------------------------
  -- GitLab
  -- --------------------------------------------------------------------------

  [".gitlab-ci.yml"] = "",
  [".gitlab-ci.yaml"] = "",

  -- --------------------------------------------------------------------------
  -- Build systems
  -- --------------------------------------------------------------------------

  ["makefile"] = "",
  ["gnumakefile"] = "",
  ["cmakelists.txt"] = "",
  ["meson.build"] = "󰔷",
  ["meson_options.txt"] = "󰔷",
  ["build.gradle"] = "",
  ["build.gradle.kts"] = "",
  ["settings.gradle"] = "",
  ["settings.gradle.kts"] = "",
  ["gradle.properties"] = "",
  ["pom.xml"] = "",
  ["build.xml"] = "",

  -- --------------------------------------------------------------------------
  -- Docker
  -- --------------------------------------------------------------------------

  ["dockerfile"] = "󰡨",
  ["dockerfile.dev"] = "󰡨",
  ["dockerfile.prod"] = "󰡨",
  ["docker-compose.yml"] = "󰡨",
  ["docker-compose.yaml"] = "󰡨",
  ["compose.yml"] = "󰡨",
  ["compose.yaml"] = "󰡨",
  [".dockerignore"] = "󰡨",

  -- --------------------------------------------------------------------------
  -- Kubernetes / Helm
  -- --------------------------------------------------------------------------

  ["chart.yaml"] = "󰠳",
  ["chart.yml"] = "󰠳",
  ["values.yaml"] = "󰠳",
  ["values.yml"] = "󰠳",
  ["kustomization.yaml"] = "󰠳",
  ["kustomization.yml"] = "󰠳",

  -- --------------------------------------------------------------------------
  -- Node / npm
  -- --------------------------------------------------------------------------

  ["package.json"] = "",
  ["package-lock.json"] = "",
  ["npm-shrinkwrap.json"] = "",
  [".npmrc"] = "",
  [".npmignore"] = "",

  -- Yarn
  ["yarn.lock"] = "",
  [".yarnrc"] = "",
  [".yarnrc.yml"] = "",

  -- pnpm
  ["pnpm-lock.yaml"] = "",
  ["pnpm-workspace.yaml"] = "",

  -- Bun
  ["bun.lock"] = "",
  ["bun.lockb"] = "",
  ["bunfig.toml"] = "",

  -- --------------------------------------------------------------------------
  -- TypeScript
  -- --------------------------------------------------------------------------

  ["tsconfig.json"] = "󰛦",
  ["tsconfig.app.json"] = "󰛦",
  ["tsconfig.node.json"] = "󰛦",
  ["tsconfig.spec.json"] = "󰛦",
  ["jsconfig.json"] = "",

  -- --------------------------------------------------------------------------
  -- Angular
  -- --------------------------------------------------------------------------

  ["angular.json"] = "",
  [".angular-cli.json"] = "",

  -- --------------------------------------------------------------------------
  -- React / Next / Remix
  -- --------------------------------------------------------------------------

  ["next.config.js"] = "",
  ["next.config.mjs"] = "",
  ["next.config.ts"] = "",
  ["next-env.d.ts"] = "",

  ["remix.config.js"] = "󰰥",

  -- --------------------------------------------------------------------------
  -- Vue / Nuxt
  -- --------------------------------------------------------------------------

  ["vue.config.js"] = "",
  ["nuxt.config.js"] = "󱄆",
  ["nuxt.config.ts"] = "󱄆",

  -- --------------------------------------------------------------------------
  -- Svelte
  -- --------------------------------------------------------------------------

  ["svelte.config.js"] = "",
  ["svelte.config.ts"] = "",

  -- --------------------------------------------------------------------------
  -- Astro
  -- --------------------------------------------------------------------------

  ["astro.config.js"] = "",
  ["astro.config.mjs"] = "",
  ["astro.config.ts"] = "",

  -- --------------------------------------------------------------------------
  -- Vite / Webpack / Rollup / Parcel
  -- --------------------------------------------------------------------------

  ["vite.config.js"] = "",
  ["vite.config.mjs"] = "",
  ["vite.config.ts"] = "",

  ["webpack.config.js"] = "󰜫",
  ["webpack.config.ts"] = "󰜫",

  ["rollup.config.js"] = "󰜫",
  ["rollup.config.mjs"] = "󰜫",
  ["rollup.config.ts"] = "󰜫",

  [".parcelrc"] = "󰏗",

  -- --------------------------------------------------------------------------
  -- Tailwind / PostCSS
  -- --------------------------------------------------------------------------

  ["tailwind.config.js"] = "󱏿",
  ["tailwind.config.cjs"] = "󱏿",
  ["tailwind.config.mjs"] = "󱏿",
  ["tailwind.config.ts"] = "󱏿",

  ["postcss.config.js"] = "",
  ["postcss.config.cjs"] = "",
  ["postcss.config.mjs"] = "",

  -- --------------------------------------------------------------------------
  -- ESLint
  -- --------------------------------------------------------------------------

  [".eslintrc"] = "",
  [".eslintrc.js"] = "",
  [".eslintrc.cjs"] = "",
  [".eslintrc.json"] = "",
  [".eslintrc.yml"] = "",
  [".eslintrc.yaml"] = "",
  ["eslint.config.js"] = "",
  ["eslint.config.mjs"] = "",
  ["eslint.config.cjs"] = "",
  ["eslint.config.ts"] = "",
  [".eslintignore"] = "",

  -- --------------------------------------------------------------------------
  -- Prettier
  -- --------------------------------------------------------------------------

  [".prettierrc"] = "",
  [".prettierrc.json"] = "",
  [".prettierrc.js"] = "",
  [".prettierrc.cjs"] = "",
  [".prettierrc.yml"] = "",
  [".prettierrc.yaml"] = "",
  ["prettier.config.js"] = "",
  ["prettier.config.cjs"] = "",
  [".prettierignore"] = "",

  -- --------------------------------------------------------------------------
  -- Biome
  -- --------------------------------------------------------------------------

  ["biome.json"] = "󰂓",
  ["biome.jsonc"] = "󰂓",

  -- --------------------------------------------------------------------------
  -- Testing
  -- --------------------------------------------------------------------------

  ["jest.config.js"] = "󰙨",
  ["jest.config.cjs"] = "󰙨",
  ["jest.config.mjs"] = "󰙨",
  ["jest.config.ts"] = "󰙨",

  ["vitest.config.js"] = "󰙨",
  ["vitest.config.mjs"] = "󰙨",
  ["vitest.config.ts"] = "󰙨",

  ["playwright.config.js"] = "󰙨",
  ["playwright.config.ts"] = "󰙨",

  ["cypress.config.js"] = "󰙨",
  ["cypress.config.ts"] = "󰙨",

  ["karma.conf.js"] = "󰙨",
  ["protractor.conf.js"] = "󰙨",

  -- --------------------------------------------------------------------------
  -- Documentation
  -- --------------------------------------------------------------------------

  ["readme"] = "",
  ["readme.md"] = "",
  ["readme.mdx"] = "",
  ["readme.txt"] = "",

  ["changelog"] = "󰚰",
  ["changelog.md"] = "󰚰",
  ["changes.md"] = "󰚰",
  ["history.md"] = "󰚰",

  ["contributing.md"] = "󰅍",
  ["contributors.md"] = "󰅍",

  ["authors"] = "",
  ["authors.md"] = "",

  ["todo"] = "󰄬",
  ["todo.md"] = "󰄬",

  -- --------------------------------------------------------------------------
  -- License
  -- --------------------------------------------------------------------------

  ["license"] = "󰿃",
  ["license.md"] = "󰿃",
  ["license.txt"] = "󰿃",
  ["copying"] = "󰿃",
  ["copyright"] = "󰿃",

  -- --------------------------------------------------------------------------
  -- Environment
  -- --------------------------------------------------------------------------

  [".env"] = "󰒓",
  [".env.local"] = "󰒓",
  [".env.development"] = "󰒓",
  [".env.development.local"] = "󰒓",
  [".env.test"] = "󰒓",
  [".env.test.local"] = "󰒓",
  [".env.production"] = "󰒓",
  [".env.production.local"] = "󰒓",
  [".env.example"] = "󰒓",
  [".env.sample"] = "󰒓",
  [".env.template"] = "󰒓",

  -- --------------------------------------------------------------------------
  -- Editor / workspace
  -- --------------------------------------------------------------------------

  [".editorconfig"] = "",
  [".ignore"] = "󰈉",

  -- VSCode
  ["settings.json"] = "",
  ["extensions.json"] = "",
  ["launch.json"] = "",
  ["tasks.json"] = "",

  -- --------------------------------------------------------------------------
  -- Go
  -- --------------------------------------------------------------------------

  ["go.mod"] = "",
  ["go.sum"] = "",
  ["go.work"] = "",
  ["go.work.sum"] = "",

  -- --------------------------------------------------------------------------
  -- Rust
  -- --------------------------------------------------------------------------

  ["cargo.toml"] = "",
  ["cargo.lock"] = "",
  ["rust-toolchain"] = "",
  ["rust-toolchain.toml"] = "",

  -- --------------------------------------------------------------------------
  -- Python
  -- --------------------------------------------------------------------------

  ["pyproject.toml"] = "",
  ["requirements.txt"] = "",
  ["requirements-dev.txt"] = "",
  ["pipfile"] = "",
  ["pipfile.lock"] = "",
  ["poetry.lock"] = "",
  ["setup.py"] = "",
  ["setup.cfg"] = "",
  ["tox.ini"] = "",
  [".python-version"] = "",

  -- --------------------------------------------------------------------------
  -- Ruby
  -- --------------------------------------------------------------------------

  ["gemfile"] = "",
  ["gemfile.lock"] = "",
  [".ruby-version"] = "",
  ["rakefile"] = "",

  -- --------------------------------------------------------------------------
  -- PHP / Composer
  -- --------------------------------------------------------------------------

  ["composer.json"] = "",
  ["composer.lock"] = "",
  ["phpunit.xml"] = "",
  ["phpunit.xml.dist"] = "",

  -- --------------------------------------------------------------------------
  -- .NET
  -- --------------------------------------------------------------------------

  ["global.json"] = "󰌛",
  ["nuget.config"] = "󰌛",
  ["directory.build.props"] = "󰌛",
  ["directory.build.targets"] = "󰌛",
  ["directory.packages.props"] = "󰌛",

  -- --------------------------------------------------------------------------
  -- Java / Maven / Gradle
  -- --------------------------------------------------------------------------

  ["mvnw"] = "",
  ["mvnw.cmd"] = "",
  ["gradlew"] = "",
  ["gradlew.bat"] = "",

  -- --------------------------------------------------------------------------
  -- Dart / Flutter
  -- --------------------------------------------------------------------------

  ["pubspec.yaml"] = "",
  ["pubspec.lock"] = "",
  ["analysis_options.yaml"] = "",

  -- --------------------------------------------------------------------------
  -- Elixir
  -- --------------------------------------------------------------------------

  ["mix.exs"] = "",
  ["mix.lock"] = "",

  -- --------------------------------------------------------------------------
  -- Terraform
  -- --------------------------------------------------------------------------

  [".terraform.lock.hcl"] = "󱁢",

  -- --------------------------------------------------------------------------
  -- Prisma
  -- --------------------------------------------------------------------------

  ["schema.prisma"] = "",

  -- --------------------------------------------------------------------------
  -- Nix
  -- --------------------------------------------------------------------------

  ["flake.nix"] = "",
  ["flake.lock"] = "",
  ["shell.nix"] = "",
  ["default.nix"] = "",

  -- --------------------------------------------------------------------------
  -- CI / CD
  -- --------------------------------------------------------------------------

  ["jenkinsfile"] = "",
  ["azure-pipelines.yml"] = "󰴊",
  ["azure-pipelines.yaml"] = "󰴊",
  ["bitbucket-pipelines.yml"] = "",

  -- --------------------------------------------------------------------------
  -- Deployment / hosting
  -- --------------------------------------------------------------------------

  ["vercel.json"] = "▲",
  ["netlify.toml"] = "",

  -- --------------------------------------------------------------------------
  -- Dependabot / Renovate
  -- --------------------------------------------------------------------------

  ["renovate.json"] = "󰚰",
  ["renovate.json5"] = "󰚰",
  [".renovaterc"] = "󰚰",
  [".renovaterc.json"] = "󰚰",

  -- --------------------------------------------------------------------------
  -- Database
  -- --------------------------------------------------------------------------

  ["docker-compose.db.yml"] = "󰆼",

  -- --------------------------------------------------------------------------
  -- Misc project files
  -- --------------------------------------------------------------------------

  [".browserslistrc"] = "󰖟",
  ["browserslist"] = "󰖟",

  [".stylelintrc"] = "",
  [".stylelintrc.json"] = "",
  ["stylelint.config.js"] = "",

  [".commitlintrc"] = "",
  [".commitlintrc.json"] = "",
  ["commitlint.config.js"] = "",

  [".lintstagedrc"] = "󰍉",
  [".lintstagedrc.json"] = "󰍉",
  ["lint-staged.config.js"] = "󰍉",

  [".huskyrc"] = "󰊢",
  [".huskyrc.json"] = "󰊢",

  ["robots.txt"] = "󰚩",
  ["sitemap.xml"] = "󰗀",

  ["favicon.ico"] = "",
}

-- ============================================================================
-- Exact filename highlight groups
-- ============================================================================

local NAME_HL = {
  -- git
  [".gitignore"] = "ExplorerIconGit",
  [".gitattributes"] = "ExplorerIconGit",
  [".gitmodules"] = "ExplorerIconGit",
  [".gitkeep"] = "ExplorerIconGit",
  [".gitconfig"] = "ExplorerIconGit",
  [".mailmap"] = "ExplorerIconGit",

  ["codeowners"] = "ExplorerIconGitHub",
  ["dependabot.yml"] = "ExplorerIconGitHub",
  ["dependabot.yaml"] = "ExplorerIconGitHub",

  [".gitlab-ci.yml"] = "ExplorerIconGitLab",
  [".gitlab-ci.yaml"] = "ExplorerIconGitLab",

  -- build
  ["makefile"] = "ExplorerIconBuild",
  ["gnumakefile"] = "ExplorerIconBuild",
  ["cmakelists.txt"] = "ExplorerIconBuild",
  ["meson.build"] = "ExplorerIconBuild",
  ["meson_options.txt"] = "ExplorerIconBuild",
  ["build.gradle"] = "ExplorerIconBuild",
  ["build.gradle.kts"] = "ExplorerIconBuild",
  ["settings.gradle"] = "ExplorerIconBuild",
  ["settings.gradle.kts"] = "ExplorerIconBuild",
  ["gradle.properties"] = "ExplorerIconBuild",
  ["pom.xml"] = "ExplorerIconBuild",
  ["build.xml"] = "ExplorerIconBuild",

  -- docker
  ["dockerfile"] = "ExplorerIconDocker",
  ["dockerfile.dev"] = "ExplorerIconDocker",
  ["dockerfile.prod"] = "ExplorerIconDocker",
  ["docker-compose.yml"] = "ExplorerIconDocker",
  ["docker-compose.yaml"] = "ExplorerIconDocker",
  ["compose.yml"] = "ExplorerIconDocker",
  ["compose.yaml"] = "ExplorerIconDocker",
  [".dockerignore"] = "ExplorerIconDocker",

  -- kubernetes
  ["chart.yaml"] = "ExplorerIconKubernetes",
  ["chart.yml"] = "ExplorerIconKubernetes",
  ["values.yaml"] = "ExplorerIconKubernetes",
  ["values.yml"] = "ExplorerIconKubernetes",
  ["kustomization.yaml"] = "ExplorerIconKubernetes",
  ["kustomization.yml"] = "ExplorerIconKubernetes",

  -- node
  ["package.json"] = "ExplorerIconPackage",
  ["package-lock.json"] = "ExplorerIconPackage",
  ["npm-shrinkwrap.json"] = "ExplorerIconPackage",
  [".npmrc"] = "ExplorerIconPackage",
  [".npmignore"] = "ExplorerIconPackage",

  ["yarn.lock"] = "ExplorerIconPackage",
  [".yarnrc"] = "ExplorerIconPackage",
  [".yarnrc.yml"] = "ExplorerIconPackage",

  ["pnpm-lock.yaml"] = "ExplorerIconPackage",
  ["pnpm-workspace.yaml"] = "ExplorerIconPackage",

  ["bun.lock"] = "ExplorerIconPackage",
  ["bun.lockb"] = "ExplorerIconPackage",
  ["bunfig.toml"] = "ExplorerIconPackage",

  -- TS
  ["tsconfig.json"] = "ExplorerIconTypeScript",
  ["tsconfig.app.json"] = "ExplorerIconTypeScript",
  ["tsconfig.node.json"] = "ExplorerIconTypeScript",
  ["tsconfig.spec.json"] = "ExplorerIconTypeScript",
  ["jsconfig.json"] = "ExplorerIconWeb",

  -- angular
  ["angular.json"] = "ExplorerIconAngular",
  [".angular-cli.json"] = "ExplorerIconAngular",

  -- react / next
  ["next.config.js"] = "ExplorerIconReact",
  ["next.config.mjs"] = "ExplorerIconReact",
  ["next.config.ts"] = "ExplorerIconReact",
  ["next-env.d.ts"] = "ExplorerIconReact",
  ["remix.config.js"] = "ExplorerIconReact",

  -- vue
  ["vue.config.js"] = "ExplorerIconVue",
  ["nuxt.config.js"] = "ExplorerIconVue",
  ["nuxt.config.ts"] = "ExplorerIconVue",

  -- svelte
  ["svelte.config.js"] = "ExplorerIconSvelte",
  ["svelte.config.ts"] = "ExplorerIconSvelte",

  -- web build tooling
  ["astro.config.js"] = "ExplorerIconWeb",
  ["astro.config.mjs"] = "ExplorerIconWeb",
  ["astro.config.ts"] = "ExplorerIconWeb",

  ["vite.config.js"] = "ExplorerIconBuild",
  ["vite.config.mjs"] = "ExplorerIconBuild",
  ["vite.config.ts"] = "ExplorerIconBuild",

  ["webpack.config.js"] = "ExplorerIconBuild",
  ["webpack.config.ts"] = "ExplorerIconBuild",
  ["rollup.config.js"] = "ExplorerIconBuild",
  ["rollup.config.mjs"] = "ExplorerIconBuild",
  ["rollup.config.ts"] = "ExplorerIconBuild",
  [".parcelrc"] = "ExplorerIconBuild",

  -- lint
  [".eslintrc"] = "ExplorerIconLint",
  [".eslintrc.js"] = "ExplorerIconLint",
  [".eslintrc.cjs"] = "ExplorerIconLint",
  [".eslintrc.json"] = "ExplorerIconLint",
  [".eslintrc.yml"] = "ExplorerIconLint",
  [".eslintrc.yaml"] = "ExplorerIconLint",
  ["eslint.config.js"] = "ExplorerIconLint",
  ["eslint.config.mjs"] = "ExplorerIconLint",
  ["eslint.config.cjs"] = "ExplorerIconLint",
  ["eslint.config.ts"] = "ExplorerIconLint",
  [".eslintignore"] = "ExplorerIconLint",

  [".prettierrc"] = "ExplorerIconLint",
  [".prettierrc.json"] = "ExplorerIconLint",
  [".prettierrc.js"] = "ExplorerIconLint",
  [".prettierrc.cjs"] = "ExplorerIconLint",
  [".prettierrc.yml"] = "ExplorerIconLint",
  [".prettierrc.yaml"] = "ExplorerIconLint",
  ["prettier.config.js"] = "ExplorerIconLint",
  ["prettier.config.cjs"] = "ExplorerIconLint",
  [".prettierignore"] = "ExplorerIconLint",

  ["biome.json"] = "ExplorerIconLint",
  ["biome.jsonc"] = "ExplorerIconLint",

  -- testing
  ["jest.config.js"] = "ExplorerIconTest",
  ["jest.config.cjs"] = "ExplorerIconTest",
  ["jest.config.mjs"] = "ExplorerIconTest",
  ["jest.config.ts"] = "ExplorerIconTest",

  ["vitest.config.js"] = "ExplorerIconTest",
  ["vitest.config.mjs"] = "ExplorerIconTest",
  ["vitest.config.ts"] = "ExplorerIconTest",

  ["playwright.config.js"] = "ExplorerIconTest",
  ["playwright.config.ts"] = "ExplorerIconTest",

  ["cypress.config.js"] = "ExplorerIconTest",
  ["cypress.config.ts"] = "ExplorerIconTest",

  ["karma.conf.js"] = "ExplorerIconTest",
  ["protractor.conf.js"] = "ExplorerIconTest",

  -- docs
  ["readme"] = "ExplorerIconDocs",
  ["readme.md"] = "ExplorerIconDocs",
  ["readme.mdx"] = "ExplorerIconDocs",
  ["readme.txt"] = "ExplorerIconDocs",

  ["changelog"] = "ExplorerIconDocs",
  ["changelog.md"] = "ExplorerIconDocs",
  ["changes.md"] = "ExplorerIconDocs",
  ["history.md"] = "ExplorerIconDocs",

  ["contributing.md"] = "ExplorerIconDocs",
  ["contributors.md"] = "ExplorerIconDocs",
  ["authors"] = "ExplorerIconDocs",
  ["authors.md"] = "ExplorerIconDocs",
  ["todo"] = "ExplorerIconDocs",
  ["todo.md"] = "ExplorerIconDocs",

  ["license"] = "ExplorerIconDocs",
  ["license.md"] = "ExplorerIconDocs",
  ["license.txt"] = "ExplorerIconDocs",
  ["copying"] = "ExplorerIconDocs",
  ["copyright"] = "ExplorerIconDocs",

  -- env
  [".env"] = "ExplorerIconEnv",
  [".env.local"] = "ExplorerIconEnv",
  [".env.development"] = "ExplorerIconEnv",
  [".env.development.local"] = "ExplorerIconEnv",
  [".env.test"] = "ExplorerIconEnv",
  [".env.test.local"] = "ExplorerIconEnv",
  [".env.production"] = "ExplorerIconEnv",
  [".env.production.local"] = "ExplorerIconEnv",
  [".env.example"] = "ExplorerIconEnv",
  [".env.sample"] = "ExplorerIconEnv",
  [".env.template"] = "ExplorerIconEnv",

  -- config
  [".editorconfig"] = "ExplorerIconConfig",
  [".ignore"] = "ExplorerIconConfig",
  ["settings.json"] = "ExplorerIconConfig",
  ["extensions.json"] = "ExplorerIconConfig",
  ["launch.json"] = "ExplorerIconConfig",
  ["tasks.json"] = "ExplorerIconConfig",

  -- go
  ["go.mod"] = "ExplorerIconGo",
  ["go.sum"] = "ExplorerIconGo",
  ["go.work"] = "ExplorerIconGo",
  ["go.work.sum"] = "ExplorerIconGo",

  -- rust
  ["cargo.toml"] = "ExplorerIconRust",
  ["cargo.lock"] = "ExplorerIconRust",
  ["rust-toolchain"] = "ExplorerIconRust",
  ["rust-toolchain.toml"] = "ExplorerIconRust",

  -- python
  ["pyproject.toml"] = "ExplorerIconPython",
  ["requirements.txt"] = "ExplorerIconPython",
  ["requirements-dev.txt"] = "ExplorerIconPython",
  ["pipfile"] = "ExplorerIconPython",
  ["pipfile.lock"] = "ExplorerIconPython",
  ["poetry.lock"] = "ExplorerIconPython",
  ["setup.py"] = "ExplorerIconPython",
  ["setup.cfg"] = "ExplorerIconPython",
  ["tox.ini"] = "ExplorerIconPython",
  [".python-version"] = "ExplorerIconPython",

  -- ruby
  ["gemfile"] = "ExplorerIconRuby",
  ["gemfile.lock"] = "ExplorerIconRuby",
  [".ruby-version"] = "ExplorerIconRuby",
  ["rakefile"] = "ExplorerIconRuby",

  -- php
  ["composer.json"] = "ExplorerIconPhp",
  ["composer.lock"] = "ExplorerIconPhp",
  ["phpunit.xml"] = "ExplorerIconPhp",
  ["phpunit.xml.dist"] = "ExplorerIconPhp",

  -- dotnet
  ["global.json"] = "ExplorerIconDotnet",
  ["nuget.config"] = "ExplorerIconDotnet",
  ["directory.build.props"] = "ExplorerIconDotnet",
  ["directory.build.targets"] = "ExplorerIconDotnet",
  ["directory.packages.props"] = "ExplorerIconDotnet",

  -- java
  ["mvnw"] = "ExplorerIconJava",
  ["mvnw.cmd"] = "ExplorerIconJava",
  ["gradlew"] = "ExplorerIconJava",
  ["gradlew.bat"] = "ExplorerIconJava",

  -- dart
  ["pubspec.yaml"] = "ExplorerIconDart",
  ["pubspec.lock"] = "ExplorerIconDart",
  ["analysis_options.yaml"] = "ExplorerIconDart",

  -- elixir
  ["mix.exs"] = "ExplorerIconElixir",
  ["mix.lock"] = "ExplorerIconElixir",

  -- terraform
  [".terraform.lock.hcl"] = "ExplorerIconTerraform",

  -- database
  ["schema.prisma"] = "ExplorerIconDatabase",

  -- nix
  ["flake.nix"] = "ExplorerIconNix",
  ["flake.lock"] = "ExplorerIconNix",
  ["shell.nix"] = "ExplorerIconNix",
  ["default.nix"] = "ExplorerIconNix",

  -- CI
  ["jenkinsfile"] = "ExplorerIconCI",
  ["azure-pipelines.yml"] = "ExplorerIconCI",
  ["azure-pipelines.yaml"] = "ExplorerIconCI",
  ["bitbucket-pipelines.yml"] = "ExplorerIconCI",

  -- misc
  ["vercel.json"] = "ExplorerIconConfig",
  ["netlify.toml"] = "ExplorerIconConfig",

  ["renovate.json"] = "ExplorerIconConfig",
  ["renovate.json5"] = "ExplorerIconConfig",
  [".renovaterc"] = "ExplorerIconConfig",
  [".renovaterc.json"] = "ExplorerIconConfig",

  [".browserslistrc"] = "ExplorerIconConfig",
  ["browserslist"] = "ExplorerIconConfig",

  [".stylelintrc"] = "ExplorerIconLint",
  [".stylelintrc.json"] = "ExplorerIconLint",
  ["stylelint.config.js"] = "ExplorerIconLint",

  [".commitlintrc"] = "ExplorerIconLint",
  [".commitlintrc.json"] = "ExplorerIconLint",
  ["commitlint.config.js"] = "ExplorerIconLint",

  [".lintstagedrc"] = "ExplorerIconLint",
  [".lintstagedrc.json"] = "ExplorerIconLint",
  ["lint-staged.config.js"] = "ExplorerIconLint",

  [".huskyrc"] = "ExplorerIconGit",
  [".huskyrc.json"] = "ExplorerIconGit",

  ["robots.txt"] = "ExplorerIconWeb",
  ["sitemap.xml"] = "ExplorerIconWeb",
  ["favicon.ico"] = "ExplorerIconImage",

  ["docker-compose.db.yml"] = "ExplorerIconDatabase",
}

-- ============================================================================
-- Core icons
-- ============================================================================

M.DIR_OPEN = "󰝰"
M.DIR_CLOSED = "󰉋"
M.SYMLINK = "󰉒"
M.FILE_DEF = ""

-- ============================================================================
-- Built-in resolver
-- ============================================================================

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

-- ============================================================================
-- Minimal mode
-- ============================================================================

local function none(_, is_dir)
  return is_dir and "▶" or " ", is_dir and "ExplorerIconDir" or "ExplorerIconDefault"
end

-- ============================================================================
-- Public resolver
-- ============================================================================

function M.resolve()
  local style = cfg.get().icons.style

  if style == "none" then
    return none
  end

  return builtin
end

return M
