local code_action = require("custom.code_action")
local rename = require("config.lsp.functions.rename")
local M = {}

-- ── Diagnostic configuration ──────────────────────────────────────────────────
local function setup_diagnostics()
  vim.diagnostic.config({

    virtual_text = false,
    -- virtual_text = {
    --   spacing = 2,
    --   prefix = "●",
    --   source = "if_many",
    --   -- format = function(d)
    --   --   return d.message:sub(1, 80)
    --   -- end,
    -- },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "󰅚 ",
        [vim.diagnostic.severity.WARN] = "󰀪 ",
        [vim.diagnostic.severity.HINT] = "󰠠 ",
        [vim.diagnostic.severity.INFO] = "󰋼 ",
      },
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      border = "rounded",
      source = "if_many",
      --  press gf inside the float to jump to the referenced location.
      focusable = true,
    },
    jump = {
      on_jump = function(diagnostic, bufnr)
        if diagnostic then
          vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor" })
        end
      end,
    },
  })
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
      if client:supports_method("textDocument/definition") then
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("LSP: Definition"))
        vim.keymap.set("n", "<S-j>", function()
          require("utils.peek").peek_definition()
        end, opts("Peek Definition"))
      end

      if client:supports_method("textDocument/declaration") then
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("LSP: Declaration"))
      end

      if client:supports_method("textDocument/signatureHelp") then
        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts("LSP: Signature help"))
      end

      if client:supports_method("textDocument/rename") then
        vim.keymap.set("n", "<leader>cr", rename.rename, opts("LSP: Rename all instances"))
      end

      if client:supports_method("textDocument/implementation") then
        vim.keymap.set("n", "gi", function()
          require("utils.peek").peek_implementation()
        end, opts("Peek Implementation"))
      end

      -- Diagnostics
      vim.keymap.set("n", "gm", function()
        require("utils.peek").peek_diagnostics()
      end, opts("Peek Diagnostics"))

      if client:supports_method("textDocument/codeAction") then
        vim.keymap.set({ "n", "x" }, "<leader>ca", function()
          local ok, err = pcall(code_action.open, {
            bufnr = buf,
          })
          if not ok then
            vim.notify("Code action menu failed: " .. tostring(err), vim.log.levels.ERROR, { title = "Code Actions" })
          end
        end, opts("Code Action"))
      end

      -- Inlay hints toggle
      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = buf })
        vim.keymap.set("n", "<leader>ch", function()
          local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
          vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
          vim.notify("Inlay hints " .. (enabled and "disabled" or "enabled"), vim.log.levels.INFO)
        end, opts("[0.12] Toggle inlay hints"))
      end

      -- [0.12-new] Document colour decorations (Restricted for performance)
      local color_fts = { css = true, scss = true, html = true, typescriptreact = true, javascriptreact = true }
      if client:supports_method("textDocument/documentColor") and color_fts[vim.bo[buf].filetype] then
        pcall(vim.lsp.document_color.enable, true, buf, { style = "background" })
      end

      -- [0.12-new] Code lens
      if client:supports_method("textDocument/codeLens") then
        vim.lsp.codelens.enable(true, { bufnr = buf })
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
        vim.keymap.set("n", "<leader>ce", function()
          local enabled = false
          if vim.lsp.linked_editing_range.is_enabled then
            enabled = vim.lsp.linked_editing_range.is_enabled({ bufnr = buf })
          elseif vim.b[buf].lsp_linked_editing_enabled ~= nil then
            enabled = vim.b[buf].lsp_linked_editing_enabled
          else
            -- Fallback: check if any client for this buffer has it enabled
            local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/linkedEditingRange" })
            for _, c in ipairs(clients) do
              if c._enabled_capabilities and c._enabled_capabilities.linked_editing_range then
                enabled = true
                break
              end
            end
          end

          vim.lsp.linked_editing_range.enable(not enabled, { bufnr = buf })
          vim.b[buf].lsp_linked_editing_enabled = not enabled
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
  local original_capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  if not ok then
    return original_capabilities
  end
  return vim.tbl_deep_extend("force", original_capabilities, blink.get_lsp_capabilities(original_capabilities))
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

-- Perform setup immediately when module is loaded
M.setup_lsps()
M.setup()

return M
