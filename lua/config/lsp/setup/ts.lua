local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

---@param client vim.lsp.Client?
function M.ts_setup(client)
  if not client or client.name ~= "vtsls" then
    return
  end

  if not client:supports_method("workspace/executeCommand") then
    return
  end

  client.commands = client.commands or {}

  client.commands["_typescript.moveToFileRefactoring"] = function(command)
    if type(command) ~= "table" or type(command.arguments) ~= "table" then
      notify("Invalid move-to-file command payload from vtsls", vim.log.levels.ERROR)
      return
    end

    local action, uri, range = table.unpack(command.arguments)

    if not action or type(uri) ~= "string" or type(range) ~= "table" then
      notify("Malformed move-to-file arguments from vtsls", vim.log.levels.ERROR)
      return
    end

    if type(range.start) ~= "table" or type(range["end"]) ~= "table" then
      notify("Invalid move-to-file range from vtsls", vim.log.levels.ERROR)
      return
    end

    local ok, fname = pcall(vim.uri_to_fname, uri)
    if not ok or type(fname) ~= "string" or fname == "" then
      notify("Failed to resolve move-to-file URI: " .. tostring(uri), vim.log.levels.ERROR)
      return
    end

    local function execute_move(target_file)
      if type(target_file) ~= "string" or target_file == "" then
        return
      end

      client:request("workspace/executeCommand", {
        command = command.command,
        arguments = { action, uri, range, target_file },
      }, function(err)
        if err then
          notify("Move-to-file refactor failed: " .. tostring(err.message or err), vim.log.levels.ERROR)
        end
      end)
    end

    client:request("workspace/executeCommand", {
      command = "typescript.tsserverRequest",
      arguments = {
        "getMoveToRefactoringFileSuggestions",
        {
          file = fname,
          startLine = range.start.line + 1,
          startOffset = range.start.character + 1,
          endLine = range["end"].line + 1,
          endOffset = range["end"].character + 1,
        },
      },
    }, function(err, result)
      if err then
        notify("Move-to-file suggestions failed: " .. tostring(err.message or err), vim.log.levels.ERROR)
        return
      end

      local files = { "Enter new path..." }

      for _, file in ipairs(vim.tbl_get(result, "body", "files") or {}) do
        if type(file) == "string" then
          files[#files + 1] = file
        end
      end

      vim.ui.select(files, {
        prompt = "Select move destination:",
        format_item = function(item)
          if item == "Enter new path..." then
            return item
          end
          return vim.fn.fnamemodify(item, ":~:.")
        end,
      }, function(choice)
        if type(choice) ~= "string" then
          return
        end

        if choice ~= "Enter new path..." then
          execute_move(choice)
          return
        end

        vim.ui.input({
          prompt = "Enter move destination:",
          default = vim.fn.fnamemodify(fname, ":h") .. "/",
          completion = "file",
        }, execute_move)
      end)
    end)
  end
end

return M
