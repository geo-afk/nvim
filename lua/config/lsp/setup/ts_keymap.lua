local M = {}

-- -------------------------------------------------------------------
-- Notify helper
-- -------------------------------------------------------------------
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

-- -------------------------------------------------------------------
-- Safely apply a code action
-- -------------------------------------------------------------------
local function apply_action(client, action, bufnr)
  if not action then
    return
  end

  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or 'utf-8')
  end

  if action.command then
    if type(action.command) == 'table' then
      client:exec_cmd(action.command, { bufnr = bufnr })
    else
      client:exec_cmd({
        command = action.command,
        arguments = action.arguments,
      }, { bufnr = bufnr })
    end
  end
end

-- -------------------------------------------------------------------
-- Pick preferred action if available
-- -------------------------------------------------------------------
local function select_best_action(actions)
  for _, action in ipairs(actions) do
    if action.isPreferred then
      return action
    end
  end
  return actions[1]
end

-- -------------------------------------------------------------------
-- Run source-level TypeScript code action
-- -------------------------------------------------------------------
local function run_source_action(client, bufnr, kind)
  if not client or not bufnr then
    notify('Invalid client or buffer', vim.log.levels.ERROR)
    return
  end

  -- Use a valid range at the cursor position
  local params = vim.lsp.util.make_range_params()
  params.context = {
    only = { kind },
    diagnostics = {},
  }

  client:request('textDocument/codeAction', params, function(err, actions)
    if err then
      notify('CodeAction error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not actions or not vim.islist(actions) or #actions == 0 then
      notify 'No code actions available'
      return
    end

    if #actions == 1 then
      apply_action(client, actions[1], bufnr)
      return
    end

    local preferred = select_best_action(actions)
    if preferred then
      apply_action(client, preferred, bufnr)
      return
    end

    vim.ui.select(actions, {
      prompt = 'Select code action:',
      format_item = function(action)
        return action.title
      end,
    }, function(choice)
      apply_action(client, choice, bufnr)
    end)
  end, bufnr)
end

-- -------------------------------------------------------------------
-- Go to TypeScript source definition
-- -------------------------------------------------------------------
local function goto_source_definition(client, bufnr)
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

  client:request('workspace/executeCommand', {
    command = 'typescript.goToSourceDefinition',
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result)
    if err then
      notify('GoToSourceDefinition error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not result or not vim.islist(result) or #result == 0 then
      notify 'No source definition found'
      return
    end

    local loc = result[1]
    if loc.targetUri then
      loc = {
        uri = loc.targetUri,
        range = loc.targetSelectionRange or loc.targetRange,
      }
    end

    vim.lsp.util.show_document(loc, { focus = true })
  end, bufnr)
end

-- -------------------------------------------------------------------
-- Find all TypeScript file references
-- -------------------------------------------------------------------
local function file_references(client, bufnr)
  local uri = vim.uri_from_bufnr(bufnr)

  client:request('workspace/executeCommand', {
    command = 'typescript.findAllFileReferences',
    arguments = { uri },
  }, function(err, result)
    if err then
      notify('FileReferences error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not result or not vim.islist(result) or #result == 0 then
      notify 'No references found'
      return
    end

    local items = vim.lsp.util.locations_to_items(result)
    vim.fn.setqflist({}, ' ', {
      title = 'TypeScript File References',
      items = items,
    })
    vim.cmd.copen()
  end, bufnr)
end

-- -------------------------------------------------------------------
-- Select TypeScript workspace version
-- -------------------------------------------------------------------
local function select_typescript_version(client, bufnr)
  client:request('workspace/executeCommand', {
    command = 'typescript.selectTypeScriptVersion',
  }, function(err)
    if err then
      notify('SelectTypeScriptVersion error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
    end
  end, bufnr)
end

-- -------------------------------------------------------------------
-- Setup keymaps (call from on_attach)
-- -------------------------------------------------------------------
function M.setup(bufnr, client)
  if not bufnr or not client then
    return
  end
  if client.name ~= 'vtsls' then
    return
  end

  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set('n', '<leader>go', function()
    run_source_action(client, bufnr, 'source.organizeImports')
  end, vim.tbl_extend('force', opts, { desc = 'Organize Imports' }))

  vim.keymap.set('n', '<leader>gM', function()
    run_source_action(client, bufnr, 'source.addMissingImports.ts')
  end, vim.tbl_extend('force', opts, { desc = 'Add Missing Imports' }))

  vim.keymap.set('n', '<leader>gu', function()
    run_source_action(client, bufnr, 'source.removeUnused.ts')
  end, vim.tbl_extend('force', opts, { desc = 'Remove Unused Imports' }))

  vim.keymap.set('n', '<leader>gD', function()
    run_source_action(client, bufnr, 'source.fixAll.ts')
  end, vim.tbl_extend('force', opts, { desc = 'Fix All Diagnostics' }))

  vim.keymap.set('n', '<leader>gV', function()
    select_typescript_version(client, bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Select TypeScript Version' }))
end

return M
