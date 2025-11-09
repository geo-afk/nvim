---@diagnostic disable: missing-parameter
-- popupmenu.lua
local Menu = require 'custom.right_menu.menu' -- your Menu class file

local PopupMenu = {}

-- Detect available context actions (LSP + URL + editing + git)
local function get_context_items()
  local items = {}
  local clients = vim.lsp.get_clients { bufnr = 0 }

  local function any_client_supports(method)
    for _, client in ipairs(clients) do
      if client.supports_method(method) then
        return true
      end
    end
    return false
  end

  -- Basic editing actions (always available)
  vim.list_extend(items, {
    'Cut line',
    'Copy line',
    'Copy word',
    'Paste',
    'Undo',
    'Redo',
    'Select all',
    'Find word',
    'Replace in line',
  })

  -- Inspect (Treesitter or similar)
  table.insert(items, 'Inspect')

  -- LSP actions if available
  if #clients > 0 then
    if any_client_supports 'textDocument/hover' then
      table.insert(items, 'Hover')
    end
    if any_client_supports 'textDocument/signatureHelp' then
      table.insert(items, 'Signature help')
    end
    if any_client_supports 'textDocument/declaration' then
      table.insert(items, 'Go to declaration')
    end
    if any_client_supports 'textDocument/definition' then
      table.insert(items, 'Go to definition')
    end
    if any_client_supports 'textDocument/typeDefinition' then
      table.insert(items, 'Go to type definition')
    end
    if any_client_supports 'textDocument/implementation' then
      table.insert(items, 'Go to implementation')
    end
    if any_client_supports 'textDocument/references' then
      table.insert(items, 'Find references')
    end
    if any_client_supports 'textDocument/rename' then
      table.insert(items, 'Rename symbol')
    end
    if any_client_supports 'textDocument/codeAction' then
      table.insert(items, 'Code actions')
    end
    table.insert(items, 'Format document')
  end

  -- Git actions if in a repo
  local git_check = vim.fn.system 'git rev-parse --is-inside-work-tree 2>/dev/null'
  local in_git = vim.trim(git_check) == 'true'
  if in_git then
    table.insert(items, 'Git blame')
    table.insert(items, 'Git status')
    table.insert(items, 'Git diff')
  end

  -- Detect URLs on current line
  local line = vim.fn.getline '.'
  for url in line:gmatch 'https?://[%w-_%.%?%.:/%+=&%%]+' do
    table.insert(items, 'Open URL')
    break -- only one needed
  end

  -- Navigation
  table.insert(items, 'Back')

  return items
end

-- Format each item
local function format_item(item)
  return '• ' .. item
end

-- Helper function to open URLs
local function open_url(url)
  local sysname = vim.loop.os_uname().sysname:lower()
  local cmd

  if sysname:match 'darwin' then
    cmd = { 'open', url }
  elseif sysname:match 'windows' then
    cmd = { 'cmd.exe', '/c', 'start', url }
  else
    cmd = { 'xdg-open', url }
  end

  vim.fn.jobstart(cmd, { detach = true })
end

-- Define what happens when user selects an item
local function perform_action(item)
  local clients = vim.lsp.get_clients { bufnr = 0 }
  local word = vim.fn.expand '<cword>'
  local line = vim.fn.getline '.'

  -- Optional telescope integration
  local ok, telescope = pcall(require, 'telescope.builtin')
  local function safe_telescope(fn)
    if ok then
      fn()
    else
      vim.notify('Telescope not available; using fallback', vim.log.levels.WARN)
    end
  end

  if item == 'Cut line' then
    vim.cmd 'normal! dd'
  elseif item == 'Copy line' then
    vim.fn.setreg('+', line)
    vim.notify('Copied line', vim.log.levels.INFO)
  elseif item == 'Copy word' then
    if word ~= '' then
      vim.fn.setreg('+', word)
      vim.notify('Copied word: ' .. word, vim.log.levels.INFO)
    end
  elseif item == 'Paste' then
    vim.cmd 'normal! P'
  elseif item == 'Undo' then
    vim.cmd 'undo'
  elseif item == 'Redo' then
    vim.cmd 'redo'
  elseif item == 'Select all' then
    vim.cmd 'normal! ggVG'
  elseif item == 'Find word' then
    if word ~= '' then
      vim.fn.setreg('/', word)
      vim.cmd 'normal! n'
    end
  elseif item == 'Replace in line' then
    if word ~= '' then
      vim.ui.input({ prompt = 'Replace ' .. word .. ' with: ' }, function(new_word)
        if new_word and new_word ~= '' then
          local line_num = vim.fn.line '.'
          -- Replace only in current line
          vim.cmd(line_num .. 's/\\<' .. vim.fn.escape(word, '/\\') .. '\\>/' .. vim.fn.escape(new_word, '/\\') .. '/g')
        end
      end)
    else
      vim.notify('No word under cursor', vim.log.levels.WARN)
    end
  elseif item == 'Inspect' then
    vim.cmd 'Inspect'
  elseif item == 'Hover' then
    vim.lsp.buf.hover()
  elseif item == 'Signature help' then
    vim.lsp.buf.signature_help()
  elseif item == 'Go to declaration' then
    vim.lsp.buf.declaration()
  elseif item == 'Go to definition' then
    vim.lsp.buf.definition()
  elseif item == 'Go to type definition' then
    vim.lsp.buf.type_definition()
  elseif item == 'Go to implementation' then
    vim.lsp.buf.implementation()
  elseif item == 'Find references' then
    if ok then
      safe_telescope(telescope.lsp_references)
    else
      vim.lsp.buf.references()
    end
  elseif item == 'Rename symbol' then
    vim.lsp.buf.rename()
  elseif item == 'Code actions' then
    vim.lsp.buf.code_action()
  elseif item == 'Format document' then
    vim.lsp.buf.format { async = true }
  elseif item == 'Git blame' then
    if pcall(vim.cmd, 'Git blame') then
      -- Fugitive available
    else
      vim.cmd('!git blame ' .. vim.fn.shellescape(vim.fn.expand '%'))
    end
  elseif item == 'Git status' then
    if pcall(vim.cmd, 'Git') then
      -- Fugitive
    else
      vim.cmd '!git status'
    end
  elseif item == 'Git diff' then
    if pcall(vim.cmd, 'Gdiffsplit') then
      -- Fugitive
    else
      vim.cmd '!git diff'
    end
  elseif item == 'Open URL' then
    -- Extract URL from current line at cursor position
    local col = vim.fn.col '.'
    for url in line:gmatch 'https?://[%w-_%.%?%.:/%+=&%%#]+' do
      local start_pos = line:find(url, 1, true)
      local end_pos = start_pos + #url - 1
      if start_pos and col >= start_pos and col <= end_pos then
        open_url(url)
        vim.notify('Opening: ' .. url, vim.log.levels.INFO)
        return
      end
    end
    vim.notify('No URL found under cursor', vim.log.levels.WARN)
  elseif item == 'Back' then
    -- Use Ctrl-O to go back in jump list (more reliable than Ctrl-T)
    vim.cmd 'normal! \x0f' -- \x0f is Ctrl-O
  end
end

-- Show the floating right-click menu
function PopupMenu.show()
  local keymaps = {
    ['<CR>'] = { desc = 'Select', fn = perform_action, close = true },
    q = { desc = 'Close', fn = function() end, close = true },
  }

  local opts = {
    legend = { include = true, style = 'horizontal' },
    resize = { horizontal = true, vertical = true },
    position = vim.fn.has 'gui_running' == 1 and 'mouse' or 'cursor',
    win_opts = {
      title = 'Right-Click Menu',
      border = 'rounded',
      style = 'minimal',
    },
  }

  local menu = Menu:new(get_context_items, format_item, keymaps, opts)
  menu()
end

-- Bind right-click to open our floating menu
function PopupMenu.setup()
  vim.keymap.set('n', '<RightMouse>', function()
    PopupMenu.show()
  end, { desc = 'Show floating right-click menu' })
end

return PopupMenu
