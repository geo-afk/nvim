local M = {}

-- Fallback notify
local notify = vim.notify or function(msg, level)
  vim.api.nvim_echo({ { msg } }, true, {})
end

-- Safely apply a code action
local function safe_apply_action(client, action)
  if not action then
    return
  end

  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, 'utf-8')
  end

  if action.command then
    local cmd = action.command
    if type(cmd) == 'table' then
      client:exec_cmd(cmd, { bufnr = action.bufnr })
    else
      client:exec_cmd({
        command = cmd,
        arguments = action.arguments,
      }, { bufnr = action.bufnr })
    end
  end
end

-- Run a specific code action kind
local function run_code_action_for_kind(client, bufnr, kind)
  if not client or not bufnr then
    notify('Invalid client or buffer for code action', vim.log.levels.ERROR)
    return
  end

  local params = vim.lsp.util.make_range_params(bufnr, 'utf-16')
  ---@diagnostic disable-next-line: inject-field
  params.context = { only = { kind }, diagnostics = {} }

  client:request('textDocument/codeAction', params, function(err, actions)
    if err then
      notify('codeAction error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end
    if not actions or vim.islist(actions) == false or #actions == 0 then
      notify('No code actions available', vim.log.levels.INFO)
      return
    end

    local action = actions[1]
    safe_apply_action(client, action)
  end, bufnr)
end

-- Go to TypeScript source definition
local function goto_source_definition(client, bufnr)
  if not client or not bufnr then
    notify('Invalid client or buffer for goToSourceDefinition', vim.log.levels.ERROR)
    return
  end

  local params = vim.lsp.util.make_position_params(bufnr, 'utf-16')

  client:request('workspace/executeCommand', {
    command = 'typescript.goToSourceDefinition',
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result)
    if err then
      notify('goToSourceDefinition error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not result or vim.islist(result) == false or #result == 0 then
      notify('No source definition found', vim.log.levels.INFO)
      return
    end

    local loc = result[1]
    if loc.targetUri or loc.targetRange then
      loc = {
        uri = loc.targetUri,
        range = loc.targetSelectionRange or loc.targetRange,
      }
    end

    if loc then
      vim.lsp.util.show_document(loc, { focus = true })
    else
      notify('Could not interpret goToSourceDefinition result', vim.log.levels.WARN)
    end
  end, bufnr)
end

-- List all file references
local function file_references(client, bufnr)
  if not client or not bufnr then
    notify('Invalid client or buffer for references', vim.log.levels.ERROR)
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  client:request('workspace/executeCommand', {
    command = 'typescript.findAllFileReferences',
    arguments = { uri },
  }, function(err, result)
    if err then
      notify('findAllFileReferences error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not result or vim.islist(result) == false or #result == 0 then
      notify('No references found', vim.log.levels.INFO)
      return
    end

    local items = vim.lsp.util.locations_to_items(result)
    if not items or #items == 0 then
      notify('No references to show', vim.log.levels.INFO)
      return
    end

    vim.fn.setqflist({}, ' ', { title = 'File References', items = items })
    vim.cmd.copen()
  end, bufnr)
end

-- Prompt TypeScript version selection
local function select_typescript_version(client, bufnr)
  if not client or not bufnr then
    notify('Invalid client or buffer for version select', vim.log.levels.ERROR)
    return
  end

  client:request('workspace/executeCommand', {
    command = 'typescript.selectTypeScriptVersion',
  }, function(err)
    if err then
      notify('selectTypeScriptVersion error: ' .. tostring(err.message or err), vim.log.levels.ERROR)
    end
  end, bufnr)
end

-- Setup keymaps (to be called from your on_attach)

function M.setup(bufnr, client)
  if not bufnr or not client then
    notify('Invalid buffer or client in setup()', vim.log.levels.ERROR)
    return
  end

  if client.name ~= 'vtsls' then
    return
  end

  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set('n', 'gX', function()
    goto_source_definition(client, bufnr)
  end, vim.tbl_extend('force', { desc = 'Go To Source Definition' }, opts))

  vim.keymap.set('n', 'gR', function()
    file_references(client, bufnr)
  end, vim.tbl_extend('force', { desc = 'File References' }, opts))

  vim.keymap.set('n', '<leader>co', function()
    run_code_action_for_kind(client, bufnr, 'source.organizeImports')
  end, vim.tbl_extend('force', { desc = 'Organize Imports' }, opts))

  vim.keymap.set('n', '<leader>cM', function()
    run_code_action_for_kind(client, bufnr, 'source.addMissingImports.ts')
  end, vim.tbl_extend('force', { desc = 'Add Missing Imports' }, opts))

  vim.keymap.set('n', '<leader>cu', function()
    run_code_action_for_kind(client, bufnr, 'source.removeUnused.ts')
  end, vim.tbl_extend('force', { desc = 'Remove Unused Imports' }, opts))

  vim.keymap.set('n', '<leader>cD', function()
    run_code_action_for_kind(client, bufnr, 'source.fixAll.ts')
  end, vim.tbl_extend('force', { desc = 'Fix All Diagnostics' }, opts))

  vim.keymap.set('n', '<leader>cV', function()
    select_typescript_version(client, bufnr)
  end, vim.tbl_extend('force', { desc = 'Select TS Workspace Version' }, opts))
end

return M
