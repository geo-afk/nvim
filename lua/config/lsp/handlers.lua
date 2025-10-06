local M = {}
local lsp, diagnostic = vim.lsp, vim.diagnostic
local aucmd, augroup = vim.api.nvim_create_autocmd, vim.api.nvim_create_augroup


-- Get capabilities with blink.cmp integration
function M.get_capabilities()
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  return require('blink.cmp').get_lsp_capabilities(original_capabilities)
end

-- aucmd("LspAttach", {
--     desc = "My LSP settings",
--     group = augroup("UserLspConfig", {}),
--     callback = function(args)
--         ---@type vim.lsp.Client
--         local client = assert(lsp.get_client_by_id(args.data.client_id))
--         setup_mappings(args.buf)
--         setup_aucmds(client, args.buf)
--
--         -- Automatically show completion
--         -- if client:supports_method(lsp.protocol.Methods.textDocument_completion) then
--         --     -- Optional: trigger autocompletion on EVERY keypress. May be slow!
--         --     local chars = {}
--         --     for i = 32, 126 do
--         --         table.insert(chars, string.char(i))
--         --     end
--         --     client.server_capabilities.completionProvider.triggerCharacters = chars
--         --
--         --     lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
--         -- end
--     end,
-- })

-- Setup keymaps (called once globally)
function M.setup_keymaps(args)
  vim.keymap.set('n', 'K', function()
    vim.lsp.buf.hover { border = 'rounded' }
  end, { desc = 'Get Descriptions' })

  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { desc = 'Go to Declaration' })
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to Implementation' })
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { desc = 'Signature Help' })
  vim.keymap.set('n', '<leader>vd', vim.diagnostic.open_float, { desc = 'open float diagnostic' })
  -- vim.keymap.set({ 'n', 'x' }, '<leader>cc', vim.lsp.codelens.run, { desc = 'run code lens' })
  -- vim.keymap.set('n', '<leader>cC', vim.lsp.codelens.refresh, { desc = 'Refresh & display codelens' })

  -- vim.keymap.set('n', '<leader>lpd', function()
  --   local params = vim.lsp.util.make_position_params(nil, 'utf-8')
  --   return vim.lsp.buf_request(vim.api.nvim_get_current_buf(), vim.lsp.protocol.Methods.textDocument_definition, params, function(_, result)
  --     if result == nil or vim.tbl_isempty(result) then
  --       return
  --     end
  --     vim.lsp.util.preview_location(result[1], { border = vim.g.FloatBorders, title = 'Preview definition', title_pos = 'left' })
  --   end)
  -- end, { desc = 'LSP: floating preview' })

  vim.keymap.set('n', '<leader>ci', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end, { desc = 'Toggle Inlay Hints' })

  local map = function(keys, func, desc, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, keys, func, { buffer = args.buf, desc = 'LSP: ' .. desc })
  end

  -- Rename the variable under your cursor.
  --  Most Language Servers support renaming across files, etc.
  map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

  -- Execute a code action, usually your cursor needs to be on top of an error
  -- or a suggestion from your LSP for this to activate.
  map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

  -- Find references for the word under your cursor.
  map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

  -- Jump to the definition of the word under your cursor.
  --  This is where a variable was first declared, or where a function is defined, etc.
  --  To jump back, press <C-t>.
  map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

  -- Fuzzy find all the symbols in your current document.
  --  Symbols are things like variables, functions, types, etc.
  map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

  -- Fuzzy find all the symbols in your current workspace.
  --  Similar to document symbols, except searches over your entire project.
  map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

  -- Jump to the type of the word under your cursor.
  --  Useful when you're not sure what type a variable is and you want to see
  --  the definition of its *type*, not where it was *defined*.
  map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
end

return M
