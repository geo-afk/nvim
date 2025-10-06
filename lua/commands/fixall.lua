vim.api.nvim_create_user_command('LspFixAll', function(args)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'ts_ls' }
  if #clients == 0 then
    vim.notify('No ts_ls client attached to buffer', vim.log.levels.WARN)
    return
  end

  local opts = {
    context = { only = { 'source.fixAll.ts' } },
    apply = true,
  }

  -- Honor command range if provided; otherwise, full buffer  document-wide fixes
  local range
  if args.range then
    range = {
      start = { args.line1 - 1, 0 },
      ['end'] = { args.line2, 0 },
    }
  else
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    range = {
      start = { 0, 0 },
      ['end'] = { line_count, 0 },
    }
  end
  opts.range = range

  vim.lsp.buf.code_action(opts)
end, { range = true })
