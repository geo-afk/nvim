-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

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

-- Detect Angular HTML files and attach Angular Tree-sitter
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'html',
  callback = function(args)
    local buf = args.buf
    local path = vim.api.nvim_buf_get_name(buf)

    -- Match *.component.html OR src/app/**/*.html
    if path:match '%.component%.html$' or path:match '/src/app/.+%.html$' then
      -- Ensure this is actually an Angular project
      local angular_json = vim.fn.findfile('angular.json', vim.fn.getcwd() .. ';')

      if angular_json ~= '' then
        if not vim.treesitter.get_parser(buf, 'angular', { error = false }) then
          vim.treesitter.start(buf, 'angular')
        end
      end
    end
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
