local code_action = require("custom.code_action")
local rename = require("config.lsp.functions.rename")
local M = {}

-- ── Diagnostic configuration ──────────────────────────────────────────────────
local function setup_diagnostics()
  vim.diagnostic.config({
    virtual_text = {
      spacing = 2,
      prefix = "●",
      source = "if_many",
      -- format = function(d)
      --   return d.message:sub(1, 80)
      -- end,
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      border = "rounded",
      source = "if_many",
      --  press gf inside the float to jump to the referenced location.
      focusable = true,
    },
  })

  local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰠠 ", Info = "󰋼 " }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end
end

-- ── Shared LspAttach handler ──────────────────────────────────────────────────
local function setup_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config_lsp_attach", { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      local buf = ev.buf
      local opts = function(desc)
        return { buffer = buf, desc = desc }
      end

      require("config.lsp.setup.ts_keymap").setup(buf, client)
      require("config.lsp.setup.go").goSemanticToken(client)
      require("config.lsp.setup.ts").ts_setup(client)

      -- Navigation (grn/gra/grr/gri/K are Neovim defaults; extras below)
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("LSP: Definition"))
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("LSP: Declaration"))
      vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts("LSP: Signature help"))
      vim.keymap.set("n", "<leader>cr", rename.rename, opts("LSP: Rename All instances"))

      vim.keymap.set("n", "<S-j>", function()
        require("utils.peek").peek_definition()
      end, { desc = "Peek Definition" })

      vim.keymap.set("n", "gi", function()
        require("utils.peek").peek_implementation()
      end, { desc = "Peek Implementation" })

      -- Diagnostics
      vim.keymap.set("n", "gm", function()
        require("utils.peek").peek_diagnostics()
      end, { desc = "Peek Diagnostics" })

      vim.keymap.set({ "n", "x" }, "<leader>ca", function()
        local ok, err = pcall(code_action.open, {
          bufnr = buf,
        })
        if not ok then
          vim.notify("Code action menu failed: " .. tostring(err), vim.log.levels.ERROR, { title = "Code Actions" })
        end
      end, { desc = "Code Action" })

      -- Inlay hints toggle
      if client:supports_method("textDocument/inlayHint") then
        vim.keymap.set("n", "<leader>lh", function()
          local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
          vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
        end, opts("[0.12] Toggle inlay hints"))
      end

      -- [0.12-new] Document colour decorations
      if client:supports_method("textDocument/documentColor") then
        pcall(vim.lsp.document_color.enable, true, buf, { style = "background" })
      end

      -- [0.12-new] Code lens toggle
      if client:supports_method("textDocument/codeLens") then
        vim.keymap.set("n", "<leader>ci", function()
          local enabled = vim.lsp.codelens.is_enabled({ bufnr = buf })
          vim.lsp.codelens.enable(not enabled, { bufnr = buf })
          vim.notify("CodeLens " .. (not enabled and "enabled" or "disabled"), vim.log.levels.INFO)
        end, opts("Toggle CodeLens"))
      end

      -- [0.12-new] Workspace diagnostics
      if client:supports_method("workspace/diagnostic") then
        vim.keymap.set("n", "<leader>dW", vim.lsp.buf.workspace_diagnostics, opts("[0.12] Workspace diagnostics"))
      end

      -- [0.12-new] Linked editing range
      -- if client:supports_method("textDocument/linkedEditingRange") then
      --   vim.keymap.set("n", "<leader>le", vim.lsp.buf.linked_editing_range, opts("[0.12] Linked editing range"))
      -- end

      -- Corrected linked editing range toggle
      if client:supports_method("textDocument/linkedEditingRange") then
        vim.keymap.set("n", "<leader>le", function()
          local enabled = vim.lsp.linked_editing_range.is_enabled({ bufnr = buf })
          vim.lsp.linked_editing_range.enable(not enabled, { bufnr = buf })
          vim.notify("Linked Editing " .. (not enabled and "enabled" or "disabled"), vim.log.levels.INFO)
        end, opts("[0.12] Toggle linked editing ranges"))
      end

      -- [0.12-new] Inline completion (ghost text from AI servers)
      if client:supports_method("textDocument/inlineCompletion") then
        vim.notify("Inline completion: " .. client.name, vim.log.levels.INFO)
      end
    end,
  })
end

-- ── Server configurations ─────────────────────────────────────────────────────
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

local function get_capabilities()
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
function M.setup_lsps()
  -- Default setup  lsp clients
  vim.lsp.config("*", {
    capabilities = get_capabilities(),
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
-- ── Utility commands ──────────────────────────────────────────────────────────
local function setup_commands()
  -- [0.12-new] vim.lsp.get_configs() – list all configured servers
  vim.api.nvim_create_user_command("LspConfigs", function()
    local configs = vim.lsp.get_configs()
    local names = vim.tbl_keys(configs)
    table.sort(names)
    vim.notify("Configured LSPs:\n  " .. table.concat(names, "\n  "), vim.log.levels.INFO)
  end, { desc = "[0.12] List all configured LSP servers" })

  -- [0.12-new] vim.lsp.is_enabled() – lightweight enabled check
  vim.api.nvim_create_user_command("LspIsEnabled", function(o)
    local name = o.args ~= "" and o.args or "lua_ls"
    local enabled = vim.lsp.is_enabled(name)
    vim.notify(name .. ": " .. (enabled and "ENABLED" or "DISABLED"), vim.log.levels.INFO)
  end, { nargs = "?", desc = "[0.12] Check if LSP config is enabled" })

  -- [0.12-new] vim.diagnostic.status() summary
  vim.api.nvim_create_user_command("DiagStatus", function()
    vim.notify("Diagnostics: " .. vim.diagnostic.status(), vim.log.levels.INFO)
  end, { desc = "[0.12] Show diagnostic status string" })
end

-- ── Public entry point ────────────────────────────────────────────────────────
function M.setup()
  setup_diagnostics()
  setup_attach()
  setup_commands()
end

-- Auto-call when required directly by init.lua
M.setup_lsps()
M.setup()

return M
