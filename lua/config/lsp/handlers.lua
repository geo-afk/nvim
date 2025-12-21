local rename = require('config.lsp.functions.rename').rename
---@diagnostic disable: missing-parameter
local M = {}

-- Get capabilities with blink.cmp integration
function M.get_capabilities()
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  return vim.tbl_deep_extend('force', original_capabilities, require('blink.cmp').get_lsp_capabilities(original_capabilities))
end

function M.setup_keymaps(args)
  local map = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, func, {
      buffer = args.buf,
      desc = 'LSP: ' .. desc,
    })
  end

  -- Hover info
  map('n', 'K', function()
    vim.lsp.buf.hover { border = 'rounded' }
  end, 'Show Hover Documentation')

  -- Declarations, Definitions, Implementations
  map('n', 'gD', vim.lsp.buf.declaration, 'Go to Declaration')
  map('n', 'gd', function()
    require('utils.peek').peek_definition()
  end, 'Peek Definition')

  map('n', 'gi', function()
    require('utils.peek').peek_implementation()
  end, 'Peek Implementation')

  -- Diagnostics
  map('n', 'gm', function()
    require('utils.peek').peek_diagnostics()
  end, 'Peek Diagnostics')

  -- Signature help
  map('n', '<C-k>', vim.lsp.buf.signature_help, 'Signature Help')

  -- Code Lens
  map({ 'n', 'x' }, '<leader>cc', vim.lsp.codelens.run, 'Run Code Lens')
  map('n', '<leader>cC', vim.lsp.codelens.refresh, 'Refresh & Display Code Lens')

  -- Inlay Hints
  map('n', '<leader>ci', function()
    local ih = vim.lsp.inlay_hint
    ih.enable(not ih.is_enabled())
  end, 'Toggle Inlay Hints')

  -- Rename
  map('n', 'grn', function()
    rename()
    -- if vim.fn.exists '*lsp_rename' == 1 then
    --   -- lsp_rename()
    -- else
    --   vim.lsp.buf.rename()
    -- end
  end, 'Rename Symbol')

  -- References & Symbols
  local tb = require 'telescope.builtin'
  map('n', 'gr', tb.lsp_references, 'Go to References')
  map('n', 'gO', tb.lsp_document_symbols, 'Document Symbols')
  map('n', 'gW', tb.lsp_dynamic_workspace_symbols, 'Workspace Symbols')
  map('n', 'grt', tb.lsp_type_definitions, 'Type Definition')
end

return M
