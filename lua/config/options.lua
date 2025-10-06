-- BACKUP AND SWAP
vim.opt.swapfile = false
vim.opt.undofile = true

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

-- =======================================================================
--  Disable Unwanted Built-in Plugins
-- =======================================================================
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- =======================================================================
--  General UI Settings
-- =======================================================================
vim.o.number = true -- Show line numbers
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
-- vim.opt.winborder = 'rounded'
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

--=================   Fold ========================
vim.opt.foldenable = false -- enable fold
vim.opt.foldlevel = 99 -- start editing with all folds opened
vim.opt.foldlevelstart = 99
vim.opt.foldmethod = 'expr' -- use tree-sitter  folding method
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldcolumn = '0' -- '0' is not bad

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
--  Shell Configuration (Nushell)
-- =======================================================================
-- vim.opt.shell = 'nu'
-- vim.opt.shellcmdflag = '--commands' -- Changed from "-c"
-- vim.opt.shellquote = ''
-- vim.opt.shellxquote = ''

-- =======================================================================
--  Legacy Vimscript Configurations
-- =======================================================================
vim.cmd 'let g:netrw_banner = 0' -- Disable netrw banner
-- vim.opt.wildignore:append { '*/node_modules/*' } -- Ignore node_modules
