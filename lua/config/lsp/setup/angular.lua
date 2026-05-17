local M = {}

local APPLY_COMPLETION_CODE_ACTION = "angular.applyCompletionCodeAction"

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Angular LS" })
end

local function is_workspace_edit(value)
  return type(value) == "table" and (type(value.changes) == "table" or type(value.documentChanges) == "table")
end

local function workspace_edits_from_command(command)
  if type(command) ~= "table" or type(command.arguments) ~= "table" then
    return nil
  end

  local edits = command.arguments[1]
  if is_workspace_edit(edits) then
    return { edits }
  end

  if type(edits) ~= "table" then
    return nil
  end

  local workspace_edits = {}
  for _, edit in ipairs(edits) do
    if is_workspace_edit(edit) then
      workspace_edits[#workspace_edits + 1] = edit
    end
  end

  return workspace_edits
end

local function apply_completion_code_action(client, command)
  local workspace_edits = workspace_edits_from_command(command)
  if not workspace_edits then
    notify("Invalid completion code action payload", vim.log.levels.ERROR)
    return
  end

  local offset_encoding = client and client.offset_encoding or "utf-16"
  for _, edit in ipairs(workspace_edits) do
    vim.lsp.util.apply_workspace_edit(edit, offset_encoding)
  end
end

local function patch_exec_cmd(client)
  if client._angular_apply_completion_code_action_patched then
    return
  end

  local original_exec_cmd = client.exec_cmd
  client.exec_cmd = function(self, command, context, handler)
    if type(command) == "table" and command.command == APPLY_COMPLETION_CODE_ACTION then
      apply_completion_code_action(self, command)
      if type(handler) == "function" then
        handler(nil, nil, context)
      end
      return
    end

    return original_exec_cmd(self, command, context, handler)
  end
  client._angular_apply_completion_code_action_patched = true
end

---@param client vim.lsp.Client?
function M.setup(client)
  if not client or client.name ~= "angularls" then
    return
  end

  client.server_capabilities.renameProvider = false
  client.commands = client.commands or {}
  client.commands[APPLY_COMPLETION_CODE_ACTION] = function(command)
    apply_completion_code_action(client, command)
  end
  patch_exec_cmd(client)
end

return M
