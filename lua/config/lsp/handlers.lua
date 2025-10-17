local M = {}
local lsp, diagnostic = vim.lsp, vim.diagnostic
local aucmd, augroup = vim.api.nvim_create_autocmd, vim.api.nvim_create_augroup

-- Get capabilities with blink.cmp integration
function M.get_capabilities()
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  return vim.tbl_deep_extend('force', original_capabilities, require('blink.cmp').get_lsp_capabilities(original_capabilities))
end

local lsp_rename = function()
  local curr_name = vim.fn.expand '<cword>'
  local value = vim.fn.input('LSP Rename: ', curr_name)
  local lsp_params = vim.lsp.util.make_position_params()

  if not value or #value == 0 or curr_name == value then
    return
  end

  -- request lsp rename
  lsp_params.newName = value
  vim.lsp.buf_request(0, 'textDocument/rename', lsp_params, function(_, res, ctx, _)
    if not res then
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    vim.lsp.util.apply_workspace_edit(res, client.offset_encoding)

    local changed_files_count = 0
    local changed_instances_count = 0

    if res.documentChanges then
      for _, changed_file in pairs(res.documentChanges) do
        changed_instances_count = changed_instances_count + #changed_file.edits
        changed_files_count = changed_files_count + 1
      end
    elseif res.changes then
      for _, changed_file in pairs(res.changes) do
        changed_instances_count = changed_instances_count + #changed_file
        changed_files_count = changed_files_count + 1
      end
    end

    -- compose the right print message
    vim.notify(
      string.format(
        'Renamed %s instance%s in %s file%s.',
        changed_instances_count,
        changed_instances_count == 1 and '' or 's',
        changed_files_count,
        changed_files_count == 1 and '' or 's'
      )
    )

    vim.cmd 'silent! wa'
  end)
end

function M.setup_keymaps(args)
  vim.keymap.set('n', 'K', function()
    vim.lsp.buf.hover { border = 'rounded' }
  end, { desc = 'Get Descriptions' })

  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { desc = 'Go to Declaration' })
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to Implementation' })
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { desc = 'Signature Help' })
  vim.keymap.set('n', '<leader>vd', vim.diagnostic.open_float, { desc = 'open float diagnostic' })
  vim.keymap.set({ 'n', 'x' }, '<leader>cc', vim.lsp.codelens.run, { desc = 'run code lens' })
  vim.keymap.set('n', '<leader>cC', vim.lsp.codelens.refresh, { desc = 'Refresh & display codelens' })

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
  -- map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
  map('grn', function()
    lsp_rename()
  end, '[R]e[n]ame')

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
