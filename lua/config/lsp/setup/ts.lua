local M = {}

---@param client vim.lsp.Client
function M.ts_setup(client)
  if not client or type(client.request) ~= 'function' then
    vim.notify('Invalid LSP client passed to ts_setup', vim.log.levels.ERROR)
    return
  end

  client.commands = client.commands or {}

  client.commands['_typescript.moveToFileRefactoring'] = function(command, ctx)
    if not command or type(command.arguments) ~= 'table' then
      vim.notify('Invalid moveToFileRefactoring command payload', vim.log.levels.ERROR)
      return
    end

    local action, uri, range = unpack(command.arguments)

    if not action or not uri or type(range) ~= 'table' then
      vim.notify('Malformed refactoring arguments from tsserver', vim.log.levels.ERROR)
      return
    end

    if not range.start or not range['end'] then
      vim.notify('Invalid range supplied for refactoring', vim.log.levels.ERROR)
      return
    end

    local fname
    local ok, err = pcall(function()
      fname = vim.uri_to_fname(uri)
    end)

    if not ok or not fname or fname == '' then
      vim.notify('Failed to resolve file from URI: ' .. tostring(uri), vim.log.levels.ERROR)
      return
    end

    local function move(newf)
      if not newf or newf == '' then
        return
      end

      client:request('workspace/executeCommand', {
        command = command.command,
        arguments = { action, uri, range, newf },
      }, function(e)
        if e then
          vim.notify('Move refactoring failed: ' .. tostring(e.message or e), vim.log.levels.ERROR)
        end
      end)
    end

    -- Request file suggestions from tsserver
    client:request('workspace/executeCommand', {
      command = 'typescript.tsserverRequest',
      arguments = {
        'getMoveToRefactoringFileSuggestions',
        {
          file = fname,
          startLine = range.start.line + 1,
          startOffset = range.start.character + 1,
          endLine = range['end'].line + 1,
          endOffset = range['end'].character + 1,
        },
      },
    }, function(e, result)
      if e then
        vim.notify('getMoveToRefactoringFileSuggestions error: ' .. tostring(e.message or e), vim.log.levels.ERROR)
        return
      end

      local files = {}

      if result and result.body and type(result.body.files) == 'table' then
        for _, f in ipairs(result.body.files) do
          if type(f) == 'string' then
            table.insert(files, f)
          end
        end
      end

      table.insert(files, 1, 'Enter new path...')

      vim.ui.select(files, {
        prompt = 'Select move destination:',
        format_item = function(item)
          if item == 'Enter new path...' then
            return item
          end
          return vim.fn.fnamemodify(item, ':~:.')
        end,
      }, function(choice)
        if type(choice) ~= 'string' then
          return
        end

        if choice == 'Enter new path...' then
          vim.ui.input({
            prompt = 'Enter move destination:',
            default = vim.fn.fnamemodify(fname, ':h') .. '/',
            completion = 'file',
          }, function(newf)
            if type(newf) == 'string' and newf ~= '' then
              move(newf)
            end
          end)
        else
          move(choice)
        end
      end)
    end)
  end
end

return M
