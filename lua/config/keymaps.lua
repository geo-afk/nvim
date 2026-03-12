local opts = { noremap = true, silent = true }

-- Linters
vim.keymap.set('n', '<leader>ll', function()
  local ok, lint = pcall(require, 'lint')
  if not ok then
    vim.notify('[lint] nvim-lint not available', vim.log.levels.ERROR)
    return
  end

  local success, err = pcall(lint.try_lint)
  if not success then
    vim.notify('[lint] Lint failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end, { desc = 'Lint current file' })

-- Optional: show last lint result
vim.keymap.set('n', '<leader>L', '<cmd>LintInfo<cr>', { desc = 'Show nvim-lint info' })

-- Panes resizing
vim.keymap.set('n', '+', ':vertical resize +5<CR>')
vim.keymap.set('n', '_', ':vertical resize -5<CR>')
vim.keymap.set('n', '=', ':resize +5<CR>')
vim.keymap.set('n', '-', ':resize -5<CR>')
--
--
vim.keymap.set('n', 'n', 'nzz', opts)

-- Select All
vim.keymap.set('n', '<C-a>', 'gg<S-v>G')

-- save file
vim.keymap.set({ 'i', 'n' }, '<C-s>', '<cmd> w <CR>', opts)

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`

vim.keymap.set('n', '<Esc>', function()
  vim.cmd 'nohlsearch'
  vim.cmd 'stopinsert'
end, { silent = true })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Resize window using <ctrl> arrow keys
vim.keymap.set('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Increase Window Height' })
vim.keymap.set('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Decrease Window Height' })
vim.keymap.set('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Decrease Window Width' })
vim.keymap.set('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase Window Width' })

-- Move Lines
vim.keymap.set('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", { desc = 'Move Down' })
vim.keymap.set('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = 'Move Up' })
vim.keymap.set('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move Down' })
vim.keymap.set('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move Up' })
vim.keymap.set('v', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = 'Move Down' })
vim.keymap.set('v', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = 'Move Up' })

-- better indenting
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

vim.keymap.set({ 'n', 'v' }, '<leader>rw', function()
  local ok, strings = pcall(require, 'utils.strings')
  if not ok then
    vim.notify('[strings] utils.strings module not found', vim.log.levels.ERROR)
    return
  end

  local success, err = pcall(strings.replace_word_under_cursor)
  if not success then
    vim.notify('[strings] replace_word_under_cursor failed: ' .. tostring(err), vim.log.levels.ERROR)
  end
end, { desc = 'Replace all `<cword>` instances in buffer' })

vim.keymap.set({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })
vim.keymap.set({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true, silent = true })

vim.keymap.set({ 'i', 'n', 's' }, '<esc>', function()
  vim.cmd 'noh'
  return '<esc>'
end, { expr = true, desc = 'Escape and Clear hlsearch' })

-- local function safe_call(module, fn, label)
--   return function()
--     local ok, mod = pcall(require, module)
--     if not ok then
--       vim.notify('[' .. label .. '] module not found', vim.log.levels.ERROR)
--       return
--     end
--
--     local success, err = pcall(mod[fn])
--     if not success then
--       vim.notify(
--         '[' .. label .. '] ' .. fn .. ' failed: ' .. tostring(err),
--         vim.log.levels.ERROR
--       )
--     end
--   end
-- end
--
-- vim.keymap.set('n', '<leader>xe', safe_call('custom.diagnostics_viewer', 'toggle', 'diagnostics'), { desc = 'Toggle Diagnostics List' })
-- vim.keymap.set('n', '<leader>xo', safe_call('custom.diagnostics_viewer', 'open',   'diagnostics'), { desc = 'Open Diagnostics List' })
-- vim.keymap.set('n', '<leader>xc', safe_call('custom.diagnostics_viewer', 'close',  'diagnostics'), { desc = 'Close Diagnostics List' })
