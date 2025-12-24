vim.opt.hlsearch = true
vim.opt.incsearch = true

-- BACKUP AND SWAP
vim.opt.swapfile = false
vim.opt.undofile = true
-- vim.opt.spell = true
-- Correct Neovim Statusline Syntax
-- ============================================================
-- setting Auto-Sessions so when session is restored on startup.
-- ============================================================
vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'

-- =======================================================================
--  Compatibility / Neovim Version Checks
-- =======================================================================
if vim.fn.has 'nvim-0.11' == 1 then
  -- When closing a window, automatically jump to the last used one
  vim.opt.tabclose:append { 'uselast' }
end

vim.opt.guicursor = {
  'n-sm:block',
  'v:hor50',
  'i-c-ci-cr-ve:ver10-InsertCursor',
  -- "i-c-ci-ve:block-InsertCursor",
  'o-r:hor50',
}

-- =======================================================================
--  Disable Unwanted Built-in Plugins
-- =======================================================================
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- =======================================================================
--  General UI Settings
-- =======================================================================
vim.o.number = true -- Show line numbers
-- vim.o.winborder = "rounded"
vim.opt.winborder = 'rounded'
vim.o.mouse = 'a' -- Enable mouse support
vim.o.showmode = false -- Don’t show mode in command line (already shown in statusline)
vim.o.laststatus = 3 -- Global statusline (instead of per window)
vim.o.cmdheight = 0 -- Hide command line unless needed
vim.o.cursorline = true -- Highlight the current line
vim.o.scrolloff = 5 -- Keep 5 lines visible above/below cursor
vim.opt.termguicolors = true -- Enable true color support
vim.g.have_nerd_font = true -- Enable Nerd Font icons if available

-- =======================================================================
--  Editing Behavior
-- =======================================================================
vim.bo.commentstring = '-- %s' -- Default comment style  Lua-like files
vim.o.tabstop = 2 -- Tab width = 2 spaces
vim.o.shiftwidth = 2 -- Indent width = 2 spaces
vim.o.expandtab = true -- Use spaces instead of tabs
vim.o.autoindent = true -- Maintain indent from previous line
vim.o.smartindent = false -- Disable smart indent
vim.o.cindent = false -- Disable C-style indent
vim.o.showtabline = 2
vim.o.wrap = false
-- =======================================================================
--  Clipboard
-- =======================================================================
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus' -- Use system clipboard
end)

-- =======================================================================
--  Search
-- =======================================================================
vim.o.ignorecase = true -- Case-insensitive search...
vim.o.smartcase = true -- ...unless uppercase is used
vim.o.inccommand = 'split' -- Live preview substitutions

-- =======================================================================
--  Performance
-- =======================================================================
vim.o.updatetime = 250 -- Faster diagnostics & CursorHold events
vim.o.timeoutlen = 300 -- Faster mapped sequence wait time

-- =======================================================================
--  Window / Split Behavior
-- =======================================================================
vim.o.splitright = true -- Vertical splits open to the right
vim.o.splitbelow = true -- Horizontal splits open below

-- =======================================================================
--  Persistent Data
-- =======================================================================
vim.o.undofile = true -- Save undo history to file

-- =======================================================================
--  Signs & Columns
-- =======================================================================
vim.o.signcolumn = 'yes' -- Always show sign column (for diagnostics, git, etc.)

-- =======================================================================
--  Lists & Invisible Characters
-- =======================================================================
vim.opt.list = true
vim.opt.listchars = {
  tab = '» ',
  trail = '·',
  nbsp = '␣',
  extends = '›',
  precedes = '‹',
  conceal = '',
}
vim.opt.showbreak = '↪ ' -- Show wrapped lines with symbol
vim.opt.fillchars = {
  fold = ' ',
  foldopen = '',
  foldclose = '',
  foldsep = ' ',
  diff = '╱',
  eob = ' ',
  horiz = '━',
  horizup = '┻',
  horizdown = '┳',
  vert = '┃',
  vertleft = '┫',
  vertright = '┣',
  verthoriz = '╋',
}

-- =======================================================================
--  Behavior on Unsaved Changes
-- =======================================================================
vim.o.confirm = true -- Ask to save when quitting with unsaved changes

-- =======================================================================
--  Plugin/Framework Specific Globals
-- =======================================================================
vim.g.lazyvim_cmp = 'blink.cmp' -- Completion plugin
vim.g.root_spec = { 'lsp', { '.git', 'lua' }, 'cwd' } -- Project root detection

-- =======================================================================
--  Shell Configuration (auto)
-- =======================================================================

local fn = vim.fn
local opt = vim.opt

-- Disable temp files globally (required for Nu, safe for pwsh)
opt.shelltemp = false

-- Disable all escaping/quoting (required for Nu)
opt.shellquote = ''
opt.shellxquote = ''
opt.shellxescape = ''

---------------------------------------------------------------------
-- Prefer NuShell if available
---------------------------------------------------------------------
if fn.executable 'nu' == 1 then
  opt.shell = 'nu'

  -- Nu flags:
  -- --stdin        : read input from stdin (no temp files)
  -- --no-newline   : do not append newline to stdout
  -- -c             : execute command
  opt.shellcmdflag = '--stdin --no-newline -c'

  -- Redirect stdout+stderr
  opt.shellredir = 'out+err> %s'

  -- Pipe used by :make and similar commands
  -- - strips ANSI
  -- - saves stderr for quickfix
  opt.shellpipe = '| complete' .. ' | update stderr { ansi strip }' .. ' | tee { get stderr | save --force --raw %s }' .. ' | into record'

---------------------------------------------------------------------
-- Fallback to PowerShell 7+ if Nu is not available
---------------------------------------------------------------------
elseif fn.executable 'pwsh' == 1 then
  -- opt.shell = 'pwsh'
  --
  -- opt.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command'
  --
  -- opt.shellredir = '| Out-File -Encoding UTF8 %s'
  -- opt.shellpipe = '| Out-File -Encoding UTF8 %s'

  -- Setting shell command flags
  vim.o.shellcmdflag =
    "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';$PSStyle.OutputRendering='plaintext';Remove-Alias -Force -ErrorAction SilentlyContinue tee;"

  -- Setting shell redirection
  vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'

  -- Setting shell pipe
  vim.o.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'

  -- Setting shell quote options
  vim.o.shellquote = ''
  vim.o.shellxquote = ''
end
