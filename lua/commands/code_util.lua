local M = {}

function M.executeBufferCodeAction(client, params)
  local bufnr = vim.api.nvim_get_current_buf()
  client:request("textDocument/codeAction", params, function(err, res)
    if err then
      vim.notify("Error getting code actions: " .. err.message, vim.log.levels.ERROR)
      return
    end
    if res == nil or vim.tbl_isempty(res) then
      vim.notify("No code actions available", vim.log.levels.INFO)
      return
    end

     _, action in ipairs(res) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
        return
      elseif action.command then
        client:exec_cmd(action.command, { bufnr = bufnr })
        return
      end
    end
  end, 0)
end

return M
