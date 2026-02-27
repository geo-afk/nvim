-- Modern Context-Aware Popup Menu for Neovim
-- Enhanced with better organization, error handling, and visual hierarchy

local M = {}

-- ============================================================================
-- Configuration
-- ============================================================================

local default_config = {
  -- Menu structure with visual hierarchy using prefixes and icons
  menu_items = {
    -- 🎯 NAVIGATION & CODE INTELLIGENCE
    { label = '→ Definition', cmd = 'lua vim.lsp.buf.definition()', requires_lsp = 'textDocument/definition', requires_word = true },
    { label = '→ Declaration', cmd = 'lua vim.lsp.buf.declaration()', requires_lsp = 'textDocument/declaration', requires_word = true },
    { label = '→ Implementation', cmd = 'lua vim.lsp.buf.implementation()', requires_lsp = 'textDocument/implementation', requires_word = true },
    { label = '→ References', cmd = 'lua vim.lsp.buf.references()', requires_lsp = 'textDocument/references', requires_word = true },
    { label = '✨ Inspect', cmd = 'Inspect' },

    { separator = true },

    -- 🔍 DIAGNOSTICS & ANALYSIS
    { label = '⚡ Show Diagnostic', cmd = 'lua vim.diagnostic.open_float()' },
    { label = '📋 All Diagnostics', cmd = 'lua vim.diagnostic.setqflist()' },
    { label = '🔧 Trouble Panel', cmd = 'Trouble diagnostics', requires_module = 'trouble' },

    { separator = true },

    -- 🔎 SEARCH & FIND
    {
      label = '🔍 Find Symbol...',
      cmd = "lua require('telescope.builtin').lsp_workspace_symbols({ default_text = vim.fn.expand('<cword>') })",
      requires_module = 'telescope.builtin',
      requires_word = true,
    },
    {
      label = '🔎 Grep Workspace...',
      cmd = "lua require('telescope.builtin').live_grep({ default_text = vim.fn.expand('<cword>') })",
      requires_module = 'telescope.builtin',
      requires_word = true,
    },
    { label = '✓ TODO Comments', cmd = 'TodoTrouble', requires_module = 'todo-comments' },
    { label = '📖 Bookmarks', cmd = "lua require('bookmarks').bookmark_list()", requires_module = 'bookmarks' },

    { separator = true },

    -- 🌿 GIT & VERSION CONTROL
    { label = '🌐 Open URL in Browser', cmd = 'normal! gx' },

    { separator = true },

    -- ✂️ CLIPBOARD OPERATIONS
    { label = '✂️ Cut', cmd = '"+x', mode = 'v' },
    { label = '📄 Copy', cmd = '"+y', mode = 'v' },
    { label = '📌 Paste', cmd = '"+gP', mode = 'n' },
    { label = '📌 Paste', cmd = '"+P', mode = 'v' },
    { label = '🗑️  Delete', cmd = '"_x', mode = 'v' },

    { separator = true },

    -- ⬚ SELECTION
    { label = '⬚ Select All', cmd = 'normal! ggVG', mode = 'n' },
    { label = '⬚ Select All', cmd = 'normal! gg0oG$', mode = 'v' },
  },

  -- Visual options
  use_icons = true, -- Include icons in labels
  auto_disable = true, -- Auto-disable unavailable items
  priority_order = true, -- Keep disabled items in place (more stable UI)
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Check if a module can be loaded
---@param mod string Module name
---@return boolean
local function has_module(mod)
  local ok = pcall(require, mod)
  return ok
end

--- Check if LSP method is available in current buffer
---@param method string LSP method name
---@return boolean
local function has_lsp_method(method)
  return #vim.lsp.get_clients { bufnr = 0, method = method } > 0
end

--- Escape special characters for vim menu commands
---@param str string
---@return string
local function escape_menu_text(str)
  -- Escape spaces, dots, backslashes and other special chars
  return str:gsub('([%. \\|])', '\\%1')
end

--- Check if menu item should be enabled
---@param item table Menu item configuration
---@param cword string Current word under cursor
---@return boolean
local function should_enable_item(item, cword)
  -- Check if word is required but not present
  if item.requires_word and cword == '' then
    return false
  end

  -- Check LSP method availability
  if item.requires_lsp and not has_lsp_method(item.requires_lsp) then
    return false
  end

  -- Check module availability
  if item.requires_module and not has_module(item.requires_module) then
    return false
  end

  return true
end

-- ============================================================================
-- Menu Building
-- ============================================================================

--- Build the popup menu with proper error handling
---@param config table Plugin configuration
local function build_menu(config)
  local cword = vim.fn.expand '<cword>'
  local separator_count = 0

  -- Clear existing menu safely
  pcall(vim.cmd, 'aunmenu PopUp')

  -- Build menu items
  for idx, item in ipairs(config.menu_items) do
    if item.separator then
      -- Create visual separator
      separator_count = separator_count + 1
      local sep_name = string.format('PopUp.-sep%d-', separator_count)
      pcall(vim.cmd, string.format('anoremenu %s <Nop>', sep_name))
    else
      -- Determine mode prefix
      local mode = item.mode or 'a'

      -- Build escaped label
      local label = item.label
      local escaped_label = escape_menu_text(label)

      -- Create menu command
      local menu_path = string.format('PopUp.%s', escaped_label)
      local menu_cmd = string.format('%snoremenu %s <%s>', mode, menu_path, item.cmd)

      -- Add menu item with error handling
      local ok, err = pcall(vim.cmd, menu_cmd)
      if not ok then
        vim.notify(string.format("Failed to create menu item '%s': %s", label, err), vim.log.levels.WARN)
      end

      -- Disable if requirements not met
      if ok and config.auto_disable and not should_enable_item(item, cword) then
        pcall(vim.cmd, string.format('amenu disable %s', menu_path))
      end
    end
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Setup the popup menu system
---@param user_config? table User configuration to merge with defaults
function M.setup(user_config)
  -- Merge user config with defaults
  local config = vim.tbl_deep_extend('force', default_config, user_config or {})

  -- Store config for access
  M._config = config

  -- Create autocommand group
  local group = vim.api.nvim_create_augroup('ModernPopupMenu', { clear = true })

  -- Register MenuPopup autocmd
  vim.api.nvim_create_autocmd('MenuPopup', {
    group = group,
    pattern = '*',
    desc = 'Build context-aware popup menu',
    callback = function()
      build_menu(config)
    end,
  })

  -- Enable right-click context menu
  vim.opt.mousemodel = 'popup_setpos'

  -- Initial build to ensure menu exists
  vim.schedule(function()
    build_menu(config)
  end)

  return M
end

--- Manually trigger menu rebuild (useful for debugging)
function M.rebuild()
  if M._config then
    build_menu(M._config)
  else
    vim.notify('Popup menu not initialized. Call setup() first.', vim.log.levels.WARN)
  end
end

--- Get current configuration
function M.get_config()
  return M._config or default_config
end

--- Add custom menu item dynamically
---@param item table Menu item configuration
---@param position? number Optional position to insert (defaults to end)
function M.add_item(item, position)
  if not M._config then
    vim.notify('Popup menu not initialized. Call setup() first.', vim.log.levels.WARN)
    return
  end

  position = position or (#M._config.menu_items + 1)
  table.insert(M._config.menu_items, position, item)
  M.rebuild()
end

--- Remove menu item by label
---@param label string Label of item to remove
function M.remove_item(label)
  if not M._config then
    vim.notify('Popup menu not initialized. Call setup() first.', vim.log.levels.WARN)
    return
  end

  for i, item in ipairs(M._config.menu_items) do
    if item.label == label then
      table.remove(M._config.menu_items, i)
      M.rebuild()
      return true
    end
  end

  return false
end

return M
