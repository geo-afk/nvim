local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function exec_command(client, bufnr, command, arguments)
  client:exec_cmd({
    command = command,
    arguments = arguments,
  }, { bufnr = bufnr }, function(err)
    if err then
      notify(command .. " failed: " .. tostring(err.message or err), vim.log.levels.ERROR)
    end
  end)
end

local function current_file(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    notify("TypeScript command requires a file on disk", vim.log.levels.WARN)
    return nil
  end
  return file
end

local function run_source_action(client, bufnr, kind)
  local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
  params.context = {
    only = { kind },
    diagnostics = {},
  }

  client:request("textDocument/codeAction", params, function(err, actions)
    if err then
      notify("Code action failed: " .. tostring(err.message or err), vim.log.levels.ERROR)
      return
    end

    if not vim.islist(actions) or #actions == 0 then
      notify("No code action available for " .. kind)
      return
    end

    local action = actions[1]
    for _, candidate in ipairs(actions) do
      if candidate.isPreferred then
        action = candidate
        break
      end
    end

    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end

    if action.command then
      client:exec_cmd(action.command, { bufnr = bufnr })
    end
  end, bufnr)
end

function M.setup(bufnr, client)
  if not client or client.name ~= "vtsls" then
    return
  end

  local opts = { buffer = bufnr, silent = true }

  if client:supports_method("workspace/executeCommand", bufnr) then
    vim.keymap.set("n", "<leader>tto", function()
      local file = current_file(bufnr)
      if not file then
        return
      end
      exec_command(client, bufnr, "typescript.organizeImports", { file })
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Organize Imports" }))

    vim.keymap.set("n", "<leader>ttS", function()
      local file = current_file(bufnr)
      if not file then
        return
      end
      exec_command(client, bufnr, "typescript.sortImports", { file })
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Sort Imports" }))

    vim.keymap.set("n", "<leader>ttu", function()
      local file = current_file(bufnr)
      if not file then
        return
      end
      exec_command(client, bufnr, "typescript.removeUnusedImports", { file })
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Remove Unused Imports" }))

    vim.keymap.set("n", "<leader>ttV", function()
      exec_command(client, bufnr, "typescript.selectTypeScriptVersion")
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Select TS Version" }))
  end

  if client:supports_method("textDocument/codeAction", bufnr) then
    vim.keymap.set("n", "<leader>ttM", function()
      run_source_action(client, bufnr, "source.addMissingImports.ts")
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Add Missing Imports" }))

    vim.keymap.set("n", "<leader>ttD", function()
      run_source_action(client, bufnr, "source.fixAll.ts")
    end, vim.tbl_extend("force", opts, { desc = "TypeScript: Fix All Diagnostics" }))
  end
end

return M
