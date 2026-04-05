local M = {}
local handler = require("config.lsp.handlers")

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),

    callback = function(args)
      handler.setup_keymaps(args)
      local codelens = require("custom.codelens")

      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        vim.notify("LSP client not found  client_id: " .. tostring(args.data.client_id), vim.log.levels.WARN)
        return
      end

      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      end

      if client:supports_method("textDocument/codeLens") then
        codelens.attach(args.buf, client)
      end

      require("config.lsp.setup.ts_keymap").setup(args.buf, client)
      -- require('config.lsp.setup.go').goSemanticToken(client)
      require("config.lsp.setup.ts").ts_setup(client)

      -- Use the modern client.supports_method API (available in nvim 0.10+)
      local function client_supports_method(lsp_client, method, bufnr)
        return lsp_client:supports_method(method, { bufnr = bufnr })
      end

      local Methods = vim.lsp.protocol.Methods or {}
      local documentHighlight = Methods.textDocument_documentHighlight or "textDocument/documentHighlight"

      -- Document highlighting setup
      if client_supports_method(client, documentHighlight, args.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
          buffer = args.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
          buffer = args.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })
        vim.api.nvim_create_autocmd("LspDetach", {
          group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = false }),
          callback = function(event2)
            vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
          end,
        })
      end

      handler.setup_color_provider(client, args.buf)
    end,
  })

  handler.setup_dynamic_capabilities()
end

M.servers = {
  gopls = "go",
  html = "html",
  sqls = "sqls",
  lua_ls = "lua_ls",
  typos_lsp = "typos_lsp",
  vtsls = "vtsls",
  angularls = "angularls",
  tailwindcss = "tailwindcss",
}

-- local function test_lsp()
--   vim.lsp.log.set_level 'trace' -- Or 'debug' for less noise
--
--   local bufnr = vim.api.nvim_get_current_buf()
--   vim.lsp.config['testing-lsp'] = {
--     cmd = { 'C:\\Users\\KoolAid\\Pictures\\Projects\\go\\LSP\\main.exe' },
--     root_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)), -- Use buffer's dir as root
--     filetypes = { 'markdown' },
--     root_markers = { { '.md' } },
--   }
--   vim.lsp.enable 'testing-lsp'
-- end

function M.setup_lsps()
  -- Default setup  lsp clients
  vim.lsp.config("*", {
    capabilities = handler.get_capabilities(),
  })

  for key, value in pairs(M.servers) do
    local ok, config = pcall(require, "config.lsp.servers." .. value)

    if ok then
      vim.lsp.config(key, config)
      vim.lsp.enable(key, true)
    else
      vim.notify("Failed to load LSP config  " .. key .. ": " .. tostring(config), vim.log.levels.WARN)
    end
  end

  vim.lsp.config("angularls", {
    on_attach = function(client)
      client.server_capabilities.renameProvider = false
    end,
  })

  -- test_lsp()
end

return M
