local M = {}
local handler = require 'config.lsp.handlers'

function M.setup()
  -- Log current Neovim version
  local version = vim.version()
  local version_string = string.format('%d.%d.%d', version.major, version.minor, version.patch)
  -- print('Current Neovim version: ' .. version_string)

  -- Check if Neovim version is 0.10 or higher
  if version.major == 0 and version.minor < 10 then
    vim.notify('This configuration requires Neovim 0.10 or higher. Current version: ' .. version_string, vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLspConfig', { clear = true }),

    callback = function(args)
      handler.setup_keymaps(args)

      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        vim.notify('LSP client not found for client_id: ' .. tostring(args.data.client_id), vim.log.levels.WARN)
        return
      end

      -- Use the modern client.supports_method API (available in nvim 0.10+)
      local function client_supports_method(lsp_client, method, bufnr)
        return lsp_client:supports_method(method, { bufnr = bufnr })
      end

      local Methods = vim.lsp.protocol.Methods or {}
      local documentHighlight = Methods.textDocument_documentHighlight or 'textDocument/documentHighlight'

      -- Document highlighting setup
      if client_supports_method(client, documentHighlight, args.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = args.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = args.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })
        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = false }),
          callback = function(event2)
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end
    end,
  })
end

M.servers = {
  gopls = 'go',
  html = 'html',
  sqls = 'sqls',
  prolog = 'prolog',
  lua_ls = 'lua_ls',
  -- typos_lsp = 'typos_lsp',
  ts_ls = 'typescript',
  angularls = 'angularls',
  tailwindcss = 'tailwindcss',
}

function M.setup_lsps()
  -- Default setup for lsp clients
  vim.lsp.config('*', {
    on_attach = handler.on_attach,
    capabilities = handler.get_capabilities(),
  })

  for key, value in pairs(M.servers) do
    local ok, config = pcall(require, 'config.lsp.servers.' .. value)

    if ok then
      vim.lsp.config(key, config)
    else
      vim.notify('Failed to load LSP config for ' .. key .. ': ' .. tostring(config), vim.log.levels.WARN)
    end
  end
  vim.lsp.enable { 'prolog' }
end

return M
