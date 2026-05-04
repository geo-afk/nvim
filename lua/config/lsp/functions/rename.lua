local lsp = vim.lsp
local api = vim.api

local function get_text_at_range(range, position_encoding)
  return api.nvim_buf_get_text(
    0,
    range.start.line,
    lsp.util._get_line_byte_from_position(0, range.start, position_encoding),
    range["end"].line,
    lsp.util._get_line_byte_from_position(0, range["end"], position_encoding),
    {}
  )[1]
end

local function get_symbol_to_rename(cb)
  local cword = vim.fn.expand("<cword>")
  local clients = lsp.get_clients({ bufnr = 0, method = "textDocument/rename" })
  if #clients == 0 then
    vim.notify("No LSP server supports rename for this file", vim.log.levels.WARN)
    return
  end
  table.sort(clients, function(a, b)
    return a:supports_method("textDocument/prepareRename") and not b:supports_method("textDocument/prepareRename")
  end)
  local client = clients[1]
  if client:supports_method("textDocument/prepareRename") then
    local params = lsp.util.make_position_params(nil, client.offset_encoding)
    client:request("textDocument/prepareRename", params, function(err, result)
      if err or not result then
        cb(cword, client)
        return
      end
      local symbol_text = cword
      if result.placeholder then
        symbol_text = result.placeholder
      elseif result.range then
        symbol_text = get_text_at_range(result.range, client.offset_encoding)
      elseif result.start and result["end"] then
        symbol_text = get_text_at_range({ start = result.start, ["end"] = result["end"] }, client.offset_encoding)
      end
      cb(symbol_text, client)
    end, 0)
  else
    cb(cword, client)
  end
end

-- Preview affected files by doing a workspace/executeCommand dry-run via references
local function get_affected_files(newName, cb)
  local clients = lsp.get_clients({ bufnr = 0, method = "textDocument/rename" })
  if #clients == 0 then
    cb({})
    return
  end
  local client = clients[1]
  local params = lsp.util.make_position_params(nil, client.offset_encoding)
  params.newName = newName
  client:request("textDocument/rename", params, function(err, result)
    if err or not result then
      cb({})
      return
    end
    local files = {}
    local seen = {}
    if result.documentChanges then
      for _, change in ipairs(result.documentChanges) do
        local uri = change.textDocument and change.textDocument.uri
        if uri and not seen[uri] then
          seen[uri] = true
          local path = vim.uri_to_fname(uri)
          local rel = vim.fn.fnamemodify(path, ":~:.")
          table.insert(files, rel)
        end
      end
    elseif result.changes then
      for uri, _ in pairs(result.changes) do
        if not seen[uri] then
          seen[uri] = true
          local path = vim.uri_to_fname(uri)
          local rel = vim.fn.fnamemodify(path, ":~:.")
          table.insert(files, rel)
        end
      end
    end
    cb(files)
  end, 0)
end

local function apply_rename_in_current_file(newName)
  local params = lsp.util.make_position_params(nil, nil)
  params.newName = newName
  local clients = lsp.get_clients({ bufnr = 0, method = "textDocument/rename" })
  if #clients == 0 then
    return
  end
  local client = clients[1]
  client:request("textDocument/rename", params, function(err, result)
    if err or not result then
      vim.notify("Rename failed: " .. (err and err.message or "no result"), vim.log.levels.ERROR)
      return
    end
    -- Filter to current buffer only
    local current_uri = vim.uri_from_bufnr(0)
    local filtered = { changes = {}, documentChanges = {} }
    if result.documentChanges then
      for _, change in ipairs(result.documentChanges) do
        if change.textDocument and change.textDocument.uri == current_uri then
          table.insert(filtered.documentChanges, change)
        end
      end
      if #filtered.documentChanges > 0 then
        lsp.util.apply_workspace_edit(filtered, client.offset_encoding)
      end
    elseif result.changes then
      if result.changes[current_uri] then
        filtered.changes[current_uri] = result.changes[current_uri]
        lsp.util.apply_workspace_edit(filtered, client.offset_encoding)
      end
    end
  end, 0)
end

local function show_affected_files_and_confirm(files, newName, on_confirm)
  local lines = { " Affected files:", "" }
  for _, f in ipairs(files) do
    table.insert(lines, "  • " .. f)
  end
  table.insert(lines, "")
  table.insert(lines, " Press <CR> to confirm, <Esc> to cancel")

  local buf = api.nvim_create_buf(false, true)
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l + 2)
  end

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - #lines) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = { { " Workspace Rename ", "@comment.danger" } },
    title_pos = "center",
  })

  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].modifiable = false

  vim.keymap.set("n", "<Esc>", function()
    api.nvim_buf_delete(buf, { force = true })
  end, { buffer = buf })

  vim.keymap.set("n", "<CR>", function()
    api.nvim_buf_delete(buf, { force = true })
    on_confirm()
  end, { buffer = buf })
end

local function show_scope_picker(to_rename, on_scope)
  local lines = {
    "",
    "  [1] Current file only",
    "  [2] Entire workspace",
    "",
  }
  local buf = api.nvim_create_buf(false, true)
  local width = 28
  local win = api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 1,
    width = width,
    height = #lines,
    style = "minimal",
    border = "single",
    title = { { " Rename Scope ", "@comment.danger" } },
    title_pos = "center",
  })
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.bo[buf].modifiable = false

  local function close()
    api.nvim_buf_delete(buf, { force = true })
  end

  vim.keymap.set("n", "<Esc>", close, { buffer = buf })
  vim.keymap.set("n", "1", function()
    close()
    on_scope("file")
  end, { buffer = buf })
  vim.keymap.set("n", "2", function()
    close()
    on_scope("workspace")
  end, { buffer = buf })
end

local function show_rename_input(to_rename, on_confirm)
  local buf = api.nvim_create_buf(false, true)
  local winopts = {
    height = 1,
    style = "minimal",
    border = "single",
    row = 1,
    col = 1,
    relative = "cursor",
    width = #to_rename + 15,
    title = { { " New Name ", "@comment.danger" } },
    title_pos = "center",
  }
  local win = api.nvim_open_win(buf, true, winopts)
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:PmenuSel"
  api.nvim_set_current_win(win)
  api.nvim_buf_set_lines(buf, 0, -1, true, { to_rename })
  vim.bo[buf].buftype = "prompt"
  vim.fn.prompt_setprompt(buf, "")
  vim.api.nvim_input("A")

  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    api.nvim_buf_delete(buf, { force = true })
  end, { buffer = buf })

  vim.fn.prompt_setcallback(buf, function(text)
    api.nvim_buf_delete(buf, { force = true })
    local newName = vim.trim(text)
    if #newName > 0 and newName ~= to_rename then
      on_confirm(newName)
    end
  end)
end

local function rename()
  local capable_clients = lsp.get_clients({ bufnr = 0, method = "textDocument/rename" })
  if #capable_clients == 0 then
    vim.notify("No LSP server attached supports renaming", vim.log.levels.INFO)
    return
  end

  get_symbol_to_rename(function(to_rename)
    show_rename_input(to_rename, function(newName)
      show_scope_picker(to_rename, function(scope)
        if scope == "file" then
          apply_rename_in_current_file(newName)
        else
          -- workspace: preview affected files first
          get_affected_files(newName, function(files)
            if #files == 0 then
              vim.lsp.buf.rename(newName)
            else
              show_affected_files_and_confirm(files, newName, function()
                vim.lsp.buf.rename(newName)
              end)
            end
          end)
        end
      end)
    end)
  end)
end

return {
  rename = rename,
}
