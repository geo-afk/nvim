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
      require("config.lsp.setup.angular").setup(client)

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
        vim.keymap.set("n", "<leader>cr", function()
          require("config.lsp.functions.rename").rename()
        end, opts("LSP: Rename all instances"))
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
          local ok_module, code_action = pcall(require, "custom.code_action")
          if not ok_module then
            vim.notify("Code action module failed: " .. tostring(code_action), vim.log.levels.ERROR, {
              title = "Code Actions",
            })
            return
          end

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
        require("custom.codelens").on_attach(client, buf)
      end

      -- [0.12-new] Workspace diagnostics
      if client:supports_method("workspace/diagnostic") then
        vim.keymap.set("n", "<leader>dW", function()
          vim.diagnostic.setqflist({ scope = "workspace" })
          vim.cmd("copen")
        end, opts("[0.12] Workspace diagnostics"))
      end

      -- [0.12-new] Linked editing range
      if client:supports_method("textDocument/linkedEditingRange") then
        vim.keymap.set("n", "<leader>ce", function()
          local next = not vim.b[buf].lsp_linked_editing_enabled
          vim.b[buf].lsp_linked_editing_enabled = next
          -- Toggle via built-in (available in 0.12 nightly) or use vim.lsp.buf
          if vim.lsp.buf.linked_editing_range then
            vim.lsp.buf.linked_editing_range()
          end
          vim.notify("Linked Editing " .. (next and "enabled" or "disabled"), vim.log.levels.INFO)
        end, opts("[0.12] Toggle linked editing ranges"))
      end

      -- [0.12-new] Inline completion (ghost text from AI servers)
      if client:supports_method("textDocument/inlineCompletion") then
        vim.notify("Inline completion: " .. client.name, vim.log.levels.INFO)
      end

      local server_capabilities = client.server_capabilities

      if server_capabilities ~= nil then
        if server_capabilities.documentHighlightProvider then
          vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "MatchParen" })
          vim.api.nvim_set_hl(0, "LspReferenceText", { link = "MatchParen" })
          vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "MatchParen" })

          local hl_group = vim.api.nvim_create_augroup("lsp_doc_hl_" .. buf, { clear = true })
          vim.api.nvim_create_autocmd("CursorHold", {
            buffer = buf,
            group = hl_group,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter" }, {
            buffer = buf,
            group = hl_group,
            callback = vim.lsp.buf.clear_references,
          })
          vim.api.nvim_create_autocmd("LspDetach", {
            buffer = buf,
            group = hl_group,
            once = true,
            callback = function()
              pcall(vim.lsp.buf.clear_references)
              pcall(vim.api.nvim_del_augroup_by_name, "lsp_doc_hl_" .. buf)
            end,
          })
        end
      end
    end,
  })
end

-- ── Server configurations ─────────────────────────────────────────────────────
M.servers = {
  gopls = "go",
  html = "html",
  jsonls = "jsonls",
  sqls = "sqls",
  lua_ls = "lua_ls",
  codebook = "codebook",
  typos_lsp = "typos_lsp",
  vtsls = "vtsls",
  biome = "biome",
  angularls = "angularls",
  tailwindcss = "tailwindcss",
}

local function get_capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  if ok then
    caps = vim.tbl_deep_extend("force", caps, blink.get_lsp_capabilities(caps))
  end
  -- Add universally useful extensions (Fix #14)
  caps.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
  caps.textDocument.colorProvider = { dynamicRegistration = false }
  return caps
end

local function ensure_mason_bin_on_path()
  local bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin")
  if vim.uv.fs_stat(bin) == nil then
    return
  end

  local sep = package.config:sub(1, 1) == "\\" and ";" or ":"
  local path = vim.env.PATH or ""
  for entry in vim.gsplit(path, sep, { plain = true }) do
    if vim.fs.normalize(entry) == vim.fs.normalize(bin) then
      return
    end
  end

  vim.env.PATH = bin .. sep .. path
end

function M.setup_lsps()
  ensure_mason_bin_on_path()

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

  vim.schedule(function()
    pcall(vim.cmd.doautoall, "nvim.lsp.enable FileType")
  end)

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

  -- Initialize custom LSP enhancements
  pcall(function()
    require("custom.codelens").setup()
  end)
end

return M
