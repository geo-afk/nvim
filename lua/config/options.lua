local opt = vim.opt

-- ── UI / appearance ───────────────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.showmode = false
opt.cmdheight = 0 -- 0.12 UI/message handling makes the reserved cmdline row unnecessary
opt.laststatus = 3
opt.winborder = "rounded"
opt.guicursor = { -- from old: fine‑tuned cursor shapes
  "n-sm:block",
  "v:hor50",
  "i-c-ci-cr-ve:ver10-InsertCursor",
  "o-r:hor50",
}

-- [0.12-new] 'pumborder' adds a border around the completion popup menu.
opt.pumborder = "rounded"
opt.pummaxwidth = 50

-- ── Completion ────────────────────────────────────────────────────────────────
opt.autocomplete = false -- blink.cmp handles completion
opt.completeopt = "menuone,noselect,popup,nearest"
opt.complete = ".,w,b,u,t,i,F,o"

-- ── Indentation ───────────────────────────────────────────────────────────────
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true -- new config uses true; old used false – keeping new
opt.autoindent = true -- from old (new didn't set it)
opt.cindent = false -- from old (new didn't set, keep disabled)

-- ── Search ────────────────────────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split" -- from old: live substitution preview

-- [0.12-new] 'maxsearchcount' caps searchcount() results
opt.maxsearchcount = 999

-- ── Files / persistence ───────────────────────────────────────────────────────
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undo"
opt.sessionoptions = "blank,buffers,curdir,help,tabpages,winsize,winpos,terminal,localoptions" -- from old
opt.autowriteall = true

-- [0.12-changed] 'shada' default excludes /tmp etc.
opt.shada = "!,'100,<50,s10,h,r/tmp,r/private"

-- quickfix stack size
opt.chistory = 10
opt.lhistory = 10

-- ── Diff ─────────────────────────────────────────────────────────────────────
opt.diffopt = "internal,filler,closeoff,indent-heuristic,inline:char"

-- ── Fills & list chars ────────────────────────────────────────────────────────
-- Merged: old fillchars + new 'foldinner' (0.12)
opt.fillchars = {
  fold = " ",
  foldopen = "",
  foldclose = "",
  foldsep = " ",
  diff = "╱",
  eob = " ",
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
  foldinner = "│", -- [0.12-new]
}

opt.list = true
opt.listchars = { -- from old, fully functional
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  extends = "›",
  precedes = "‹",
  conceal = "",
}
opt.showbreak = "↪ " -- from old

-- ── Splits / windows ─────────────────────────────────────────────────────────
opt.splitright = true
opt.splitbelow = true
-- When closing a window, jump to last used one (from old)
vim.opt.tabclose:append("uselast")

-- ── Performance ───────────────────────────────────────────────────────────────
opt.updatetime = 250 -- old used 250 (faster than new's 300)
opt.timeoutlen = 300 -- old used 300 (new used 400)
opt.synmaxcol = 300

-- ── Clipboard ────────────────────────────────────────────────────────────────
if not vim.env.SSH_TTY then
  opt.clipboard = "unnamedplus"
end

-- ── Message options ───────────────────────────────────────────────────────────
opt.messagesopt = "hit-enter,history:500,progress:c"

-- ── 'exrc' (project-local config) ────────────────────────────────────────────
opt.exrc = true

-- ── Misc ─────────────────────────────────────────────────────────────────────
opt.mouse = "a"
opt.linebreak = true
opt.spelllang = "en_us"
opt.showtabline = 2 -- from old
opt.confirm = true -- ask to save on quit with unsaved changes

-- ── Wildmenu / wildchar ───────────────────────────────────────────────────────
opt.wildmode = "longest:full,full"
opt.wildignore = "*.o,*.pyc,*/.git/*,*/node_modules/*"

-- ── Plugin / framework globals ───────────────────────────────────────────────
vim.g.have_nerd_font = true -- from old
vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" } -- from old

-- Disable built‑in netrw (old config)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Default comment string (Lua style)
vim.bo.commentstring = "-- %s"

-- ── Shell configuration (preserved from old config) ───────────────────────────
-- Uses NuShell if available, falls back to PowerShell 7+
local fn = vim.fn

opt.shelltemp = false
opt.shellquote = ""
opt.shellxquote = ""
opt.shellxescape = ""

if fn.executable("nu") == 1 then
  opt.shell = "nu"
  opt.shellcmdflag = "--stdin --no-newline -c"
  opt.shellredir = "out+err> %s"
  opt.shellpipe = "| complete"
    .. " | update stderr { ansi strip }"
    .. " | tee { get stderr | save --force --raw %s }"
    .. " | into record"
elseif fn.executable("pwsh") == 1 then
  opt.shellcmdflag =
    "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';$PSStyle.OutputRendering='plaintext';Remove-Alias -Force -ErrorAction SilentlyContinue tee;"
  opt.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
  opt.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'
  opt.shellquote = ""
  opt.shellxquote = ""
end
