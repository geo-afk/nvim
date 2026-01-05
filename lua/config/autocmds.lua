-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Create an autocmd for both TypeScript and HTML files
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'typescript', 'html' }, -- both filetypes
  callback = function()
    if require('utils').is_angular_project() then
      -- Buffer-local keymap
      vim.keymap.set('n', '<leader>at', function()
        -- Example: Toggle between .ts and .html
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:match '%.ts$' then
          vim.cmd('edit ' .. bufname:gsub('%.ts$', '.html'))
        elseif bufname:match '%.html$' then
          vim.cmd('edit ' .. bufname:gsub('%.html$', '.ts'))
        end
      end, { buffer = true, desc = 'Toggle Angular .ts <-> .html' })
    end
  end,
})

local function augroup(name)
  return vim.api.nvim_create_augroup('lazyvim_' .. name, { clear = true })
end

vim.api.nvim_create_autocmd('InsertLeave', { command = 'set relativenumber', pattern = '*' })
vim.api.nvim_create_autocmd('InsertEnter', { command = 'set norelativenumber', pattern = '*' })

-- Enable spell checking  certain file types
vim.api.nvim_create_autocmd(
  { 'BufRead', 'BufNewFile' },
  -- { pattern = { "*.txt", "*.md", "*.tex" }, command = [[setlocal spell<cr> setlocal spelllang=en,de<cr>]] }
  {
    pattern = { '*.txt', '*.md', '*.tex' },
    callback = function()
      vim.opt.spell = true
      vim.opt.spelllang = 'en'
    end,
  }
)

--------------------------------------------------------------------------------
-- AUTO-SAVE
--------------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged', 'BufLeave', 'FocusLost' }, {
  desc = 'User: Auto-save',
  callback = function(ctx)
    local saveInstantly = ctx.event == 'FocusLost' or ctx.event == 'BufLeave'
    local bufnr = ctx.buf
    local bo, b = vim.bo[bufnr], vim.b[bufnr]
    local bufname = ctx.file
    if bo.buftype ~= '' or bo.ft == 'gitcommit' or bo.readonly then
      return
    end
    if b.saveQueued and not saveInstantly then
      return
    end

    b.saveQueued = true
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.api.nvim_buf_call(bufnr, function()
        -- saving with explicit name prevents issues when changing `cwd`
        -- `:update!` suppresses "The file has been changed since reading it!!!"
        local vimCmd = ('silent! noautocmd lockmarks update! %q'):format(bufname)
        vim.cmd(vimCmd)
      end)
      b.saveQueued = false
    end, saveInstantly and 0 or 2000)
  end,
})

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_user_command('LspNames', function()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    print 'No active LSP clients'
  else
    for _, client in pairs(clients) do
      print(client.name)
    end
  end
end, {})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'wrap_spell',
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  group = augroup 'auto_create_dir',
  callback = function(event)
    if event.match:match '^%w%w+:[\\/][\\/]' then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

-- create group once (clear = true to avoid duplicates)
local no_auto_comment_grp = vim.api.nvim_create_augroup('NoAutoComment', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = no_auto_comment_grp,
  pattern = '*', -- all filetypes
  callback = function()
    -- Remove individually
    vim.opt_local.formatoptions:remove 'r'
    vim.opt_local.formatoptions:remove 'o'
    vim.opt_local.formatoptions:remove 'c' -- if you also want to stop auto-wrap of comments
  end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('close_with_q', { clear = true }),
  pattern = {
    'PlenaryTestPopup',
    'help',
    'lspinfo',
    'man',
    'notify',
    'qf',
    'spectre_panel',
    'startuptime',
    'tsplayground',
    'neotest-output',
    'checkhealth',
    'neotest-summary',
    'neotest-output-panel',
    'checkhealth',
    'dbout',
    'gitsigns-blame',
    'neotest-output',
    'neotest-summary',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = event.buf, silent = true })
    vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { buffer = event.buf, silent = true })
  end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ 'VimResized' }, {
  group = augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup 'last_loc',
  callback = function(event)
    local exclude = { 'gitcommit' }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Context-aware popup menu (Overrides $VIMRUNTIME/lua/vim/_defaults.lua)
local function has_module(mod)
  return pcall(require, mod)
end

local function has_lsp_method(method)
  return #vim.lsp.get_clients { bufnr = 0, method = method } > 0
end

local popupmenu_group = vim.api.nvim_create_augroup('popupmenu', { clear = true })

vim.api.nvim_create_autocmd('MenuPopup', {
  group = popupmenu_group,
  pattern = '*',
  callback = function()
    local cword = vim.fn.expand '<cword>'

    vim.cmd [[
      aunmenu PopUp

      anoremenu PopUp.Inspect                 <cmd>Inspect<CR>
      anoremenu PopUp.Definition              <cmd>lua vim.lsp.buf.definition()<CR>
      anoremenu PopUp.References              <cmd>lua vim.lsp.buf.references()<CR>
      anoremenu PopUp.Implementation          <cmd>lua vim.lsp.buf.implementation()<CR>
      anoremenu PopUp.Declaration             <cmd>lua vim.lsp.buf.declaration()<CR>
      anoremenu PopUp.-1-                     <Nop>

      anoremenu PopUp.Diagnostics\ (Trouble)  <cmd>Trouble diagnostics<CR>
      anoremenu PopUp.Show\ Diagnostics       <cmd>lua vim.diagnostic.open_float()<CR>
      anoremenu PopUp.Show\ All\ Diagnostics  <cmd>lua vim.diagnostic.setqflist()<CR>
      anoremenu PopUp.Configure\ Diagnostics  <cmd>help vim.diagnostic.config()<CR>
      anoremenu PopUp.-2-                     <Nop>

      anoremenu PopUp.Find\ symbol            <cmd>lua require('telescope.builtin').lsp_workspace_symbols({ default_text = vim.fn.expand('<cword>') })<CR>
      anoremenu PopUp.Grep                   <cmd>lua require('telescope.builtin').live_grep({ default_text = vim.fn.expand('<cword>') })<CR>
      anoremenu PopUp.TODOs                  <cmd>TodoTrouble<CR>
      anoremenu PopUp.Bookmarks              <cmd>lua require('bookmarks').bookmark_list()<CR>

      anoremenu PopUp.LazyGit                <cmd>lua require('snacks').lazygit()<CR>
      anoremenu PopUp.Open\ Git\ in\ browser  <cmd>lua require('snacks').gitbrowse()<CR>
      anoremenu PopUp.Open\ in\ web\ browser  gx
      anoremenu PopUp.-3-                     <Nop>

      vnoremenu PopUp.Cut                    "+x
      vnoremenu PopUp.Copy                  "+y
      anoremenu PopUp.Paste                 "+gP
      vnoremenu PopUp.Paste                 "+P
      vnoremenu PopUp.Delete                "_x
      nnoremenu PopUp.Select\ All            ggVG
      vnoremenu PopUp.Select\ All            gg0oG$
      inoremenu PopUp.Select\ All            <C-Home><C-O>VG
    ]]

    -- ===== LSP checks =====
    if cword == '' or not has_lsp_method 'textDocument/definition' then
      vim.cmd 'amenu disable PopUp.Definition'
    end
    if cword == '' or not has_lsp_method 'textDocument/references' then
      vim.cmd 'amenu disable PopUp.References'
    end
    if cword == '' or not has_lsp_method 'textDocument/implementation' then
      vim.cmd 'amenu disable PopUp.Implementation'
    end
    if cword == '' or not has_lsp_method 'textDocument/declaration' then
      vim.cmd 'amenu disable PopUp.Declaration'
    end

    -- ===== Plugin checks =====
    if cword == '' or not has_module 'telescope.builtin' then
      vim.cmd 'amenu disable PopUp.Find\\ symbol'
      vim.cmd 'amenu disable PopUp.Grep'
    end

    if not has_module 'trouble' then
      vim.cmd 'amenu disable PopUp.Diagnostics\\ \\(Trouble\\)'
    end

    if not has_module 'todo-comments' then
      vim.cmd 'amenu disable PopUp.TODOs'
    end

    if not has_module 'bookmarks' then
      vim.cmd 'amenu disable PopUp.Bookmarks'
    end

    if not has_module 'snacks' then
      vim.cmd [[
        amenu disable PopUp.LazyGit
        amenu disable PopUp.Open\ Git\ in\ browser
      ]]
    end
  end,
})
