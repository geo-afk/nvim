local rename = require("config.lsp.functions.rename").rename
---@diagnostic disable: missing-parameter
local M = {}

-- Get capabilities with blink.cmp integration
function M.get_capabilities()
  -- local t = { workspace = {
  --   fileOperations = {
  --     didRename = true,
  --     willRename = true,
  --   },
  -- } }
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  return vim.tbl_deep_extend(
    "force",
    original_capabilities,
    require("blink.cmp").get_lsp_capabilities(original_capabilities)
  )
end

-- New
function M.setup_color_provider(client, bufnr)
  if client:supports_method("textDocument/documentColor") and vim.lsp.document_color then
    vim.lsp.document_color.enable(true, bufnr, { style = "virtual" })
  end
end

-- Add this to your handler.lua
function M.setup_dynamic_capabilities()
  -- Override the registerCapability handler
  local original_handler = vim.lsp.handlers["client/registerCapability"]

  vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
    local result = original_handler(err, res, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)

    if not client then
      return result
    end

    -- Handle dynamic document highlighting
    for bufnr, _ in pairs(client.attached_buffers) do
      if client.server_capabilities.documentHighlightProvider then
        local group = vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })
        vim.api.nvim_clear_autocmds({ buffer = bufnr, group = group })
        vim.api.nvim_create_autocmd("CursorHold", {
          callback = vim.lsp.buf.document_highlight,
          buffer = bufnr,
          group = group,
        })
        vim.api.nvim_create_autocmd("CursorMoved", {
          callback = vim.lsp.buf.clear_references,
          buffer = bufnr,
          group = group,
        })
      end

      -- Handle dynamic color provider
      M.setup_color_provider(client, bufnr)
    end

    return result
  end
end

function M.setup_keymaps(args)
  local map = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, func, {
      buffer = args.buf,
      desc = "LSP: " .. desc,
    })
  end

  -- Hover info
  map("n", "K", function()
    vim.lsp.buf.hover({ border = "rounded" })
  end, "Show Hover Documentation")

  -- Declarations, Definitions, Implementations
  map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")
  map("n", "gd", vim.lsp.buf.definition, "Goto Definition")

  map("n", "<S-j>", function()
    require("utils.peek").peek_definition()
  end, "Peek Definition")

  map("n", "gi", function()
    require("utils.peek").peek_implementation()
  end, "Peek Implementation")

  -- Diagnostics
  map("n", "gm", function()
    require("utils.peek").peek_diagnostics()
  end, "Peek Diagnostics")
  --
  -- Signature help
  map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

  -- Code Lens
  map({ "n", "x" }, "<leader>cc", vim.lsp.codelens.run, "Run Code Lens")
  map("n", "<leader>cC", vim.lsp.codelens.refresh, "Refresh & Display Code Lens")

  -- Inlay Hints
  map("n", "<leader>ci", function()
    local ih = vim.lsp.inlay_hint
    ih.enable(not ih.is_enabled())
  end, "Toggle Inlay Hints")

  -- Rename
  map("n", "grn", function()
    rename()
    -- if vim.fn.exists '*lsp_rename' == 1 then
    --   -- lsp_rename()
    -- else
    --   vim.lsp.buf.rename()
    -- end
  end, "Rename Symbol")

  -- References & Symbols
  local tb = require("telescope.builtin")
  map("n", "gr", tb.lsp_references, "Go to References")
  map("n", "gO", tb.lsp_document_symbols, "Document Symbols")
  map("n", "gW", tb.lsp_dynamic_workspace_symbols, "Workspace Symbols")
  map("n", "grt", tb.lsp_type_definitions, "Type Definition")
end

return M
