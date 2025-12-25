local lsp = vim.lsp
local api = vim.api

local function get_text_at_range(range, position_encoding)
  return api.nvim_buf_get_text(
    0,
    range.start.line,
    lsp.util._get_line_byte_from_position(0, range.start, position_encoding),
    range['end'].line,
    lsp.util._get_line_byte_from_position(0, range['end'], position_encoding),
    {}
  )[1]
end

local function get_symbol_to_rename(cb)
  local cword = vim.fn.expand '<cword>'

  -- Get only clients that actually support rename
  local clients = lsp.get_clients { bufnr = 0, method = 'textDocument/rename' }

  if #clients == 0 then
    vim.notify('No LSP server supports rename for this file', vim.log.levels.WARN)
    return
  end

  -- Prefer clients that support prepareRename
  table.sort(clients, function(a, b)
    return a:supports_method 'textDocument/prepareRename' and not b:supports_method 'textDocument/prepareRename'
  end)

  local client = clients[1]

  if client:supports_method 'textDocument/prepareRename' then
    local params = lsp.util.make_position_params(nil, client.offset_encoding)
    client:request('textDocument/prepareRename', params, function(err, result)
      if err or not result then
        cb(cword)
        return
      end

      local symbol_text = cword
      if result.placeholder then
        symbol_text = result.placeholder
      elseif result.range then
        symbol_text = get_text_at_range(result.range, client.offset_encoding)
      elseif result.start and result['end'] then
        symbol_text = get_text_at_range({ start = result.start, ['end'] = result['end'] }, client.offset_encoding)
      end
      cb(symbol_text)
    end, 0)
  else
    cb(cword)
  end
end

local function rename()
  -- Early exit if no client supports rename
  local capable_clients = lsp.get_clients { bufnr = 0, method = 'textDocument/rename' }
  if #capable_clients == 0 then
    vim.notify('No LSP server attached supports renaming', vim.log.levels.INFO)
    return
  end

  get_symbol_to_rename(function(to_rename)
    local buf = api.nvim_create_buf(false, true)
    local winopts = {
      height = 1,
      style = 'minimal',
      border = 'single',
      row = 1,
      col = 1,
      relative = 'cursor',
      width = #to_rename + 15,
      title = { { ' New Name ', '@comment.danger' } },
      title_pos = 'center',
    }
    local win = api.nvim_open_win(buf, true, winopts)
    vim.wo[win].winhl = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:PmenuSel'

    api.nvim_set_current_win(win)
    api.nvim_buf_set_lines(buf, 0, -1, true, { to_rename })
    vim.bo[buf].buftype = 'prompt'
    vim.fn.prompt_setprompt(buf, '')
    vim.api.nvim_input 'A' -- Move to end

    -- Cancel with Esc
    vim.keymap.set({ 'i', 'n' }, '<Esc>', function()
      api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf })

    -- Confirm with Enter
    vim.fn.prompt_setcallback(buf, function(text)
      api.nvim_buf_delete(buf, { force = true })
      local newName = vim.trim(text)
      if #newName > 0 and newName ~= to_rename then
        vim.lsp.buf.rename(newName) -- Safe: we already checked capable clients exist
      end
    end)
  end)
end

return {
  rename = rename,
}
