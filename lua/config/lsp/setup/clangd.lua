local M = {}

local function switch_source_header(bufnr, client)
  local params = { uri = vim.uri_from_bufnr(bufnr) }
  client:request("textDocument/switchSourceHeader", params, function(err, result)
    if err then
      vim.notify("Error switching source/header: " .. tostring(err.message or err), vim.log.levels.ERROR, {
        title = "Clangd",
      })
      return
    end

    if not result or result == "" then
      vim.notify("Corresponding header/source file not found", vim.log.levels.WARN, {
        title = "Clangd",
      })
      return
    end

    vim.api.nvim_command("edit " .. vim.uri_to_fname(result))
  end, bufnr)
end

---@param bufnr integer
---@param client vim.lsp.Client?
function M.setup(bufnr, client)
  if not client or client.name ~= "clangd" then
    return
  end

  vim.api.nvim_buf_create_user_command(bufnr, "ClangdSwitchSourceHeader", function()
    switch_source_header(bufnr, client)
  end, { desc = "Switch between C/C++ source and header" })

  vim.keymap.set("n", "<leader>cs", function()
    switch_source_header(bufnr, client)
  end, { buffer = bufnr, desc = "LSP: Switch Source/Header" })
end

return M
