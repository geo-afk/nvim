-- =============================================================================
--  plugins/mason.lua  ·  Mason + mason-lspconfig + mason-tool-installer
--
--  Server list and mason package names sourced from the user's lsp.lua.
--  mason.nvim handles download/installation; vim.lsp.config/enable() (0.12)
--  handles the runtime wiring (see config/lsp.lua).
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/mason-org/mason.nvim" },
  { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
  { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
})

-- ── LSP servers (vim.lsp server name → Mason package name) ───────────────────
local lsp_to_mason = {
  lua_ls = "lua-language-server",
  angularls = "angular-language-server",
  emmet_language_server = "emmet-language-server",
  vtsls = "vtsls",
  gopls = "gopls",
  html = "html-lsp",
  cssls = "css-lsp",
  sqls = "sqls",
  tailwindcss = "tailwindcss-language-server",
  typos_lsp = "typos-lsp",
  -- pyright               = "pyright",
  marksman = "marksman",
  -- taplo                 = "taplo",
  -- clangd                = "clangd",
  jsonls = "json-lsp",
}

-- Formatters, linters, DAP adapters
local mason_tools = {
  -- Go
  "gofumpt",
  "goimports",
  "golines",
  "gotests",
  "staticcheck",
  "iferr",
  "gomodifytags",
  -- JS/TS
  "biome",
  "prettierd",
  -- Lua
  "stylua",
  -- Python
  "ruff",
  -- Shell
  -- "shfmt", "shellcheck",
  -- Markdown
  -- "markdownlint",
  -- DAP
  -- "debugpy",
  -- "codelldb",
  -- "delve",
}

-- ── 1. mason.nvim ─────────────────────────────────────────────────────────────
local mason_ok, mason = pcall(require, "mason")
if not mason_ok then
  vim.notify("mason.nvim not installed – restart Neovim to install", vim.log.levels.WARN)
  return
end

mason.setup({
  install_root_dir = vim.fn.stdpath("data") .. "/mason",
  ui = {
    border = "rounded",
    width = 0.85,
    height = 0.8,
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
    keymaps = {
      toggle_package_expand = "<CR>",
      install_package = "i",
      update_package = "u",
      check_package_version = "c",
      update_all_packages = "U",
      check_outdated_packages = "C",
      uninstall_package = "X",
      cancel_installation = "<C-c>",
    },
  },
  pip = { upgrade_pip = true },
})

-- ── 2. Auto-install LSP servers via registry ──────────────────────────────────
local registry_ok, registry = pcall(require, "mason-registry")
if registry_ok then
  -- Collect all Mason package names
  local ensure = {}
  for _, pkg in pairs(lsp_to_mason) do
    table.insert(ensure, pkg)
  end
  vim.list_extend(ensure, mason_tools)

  registry.refresh(function()
    for _, pkg_name in ipairs(ensure) do
      local ok2, pkg = pcall(registry.get_package, pkg_name)
      if ok2 and not pkg:is_installed() then
        pkg:install():once(
          "install:success",
          vim.schedule_wrap(function()
            vim.notify("[Mason] Installed: " .. pkg_name, vim.log.levels.INFO)
          end)
        )
      elseif not ok2 then
        vim.notify("[Mason] Package not found in registry: " .. pkg_name, vim.log.levels.WARN)
      end
    end
  end)
end

-- ── 3. mason-lspconfig – catch-all handler for unlisted servers ───────────────
local mlsp_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if mlsp_ok then
  mason_lspconfig.setup({
    -- Servers with detailed config in config/lsp.lua are handled there.
    -- This catch-all enables any Mason-installed server not explicitly configured.
    handlers = {
      function(server_name)
        -- Servers with rich config in config/lsp.lua – skip here
        local explicit = {
          lua_ls = true,
          vtsls = true,
          gopls = true,
          pyright = true,
          rust_analyzer = true,
          cssls = true,
          html = true,
          jsonls = true,
          angularls = true,
          tailwindcss = true,
          sqls = true,
          emmet_language_server = true,
          typos_lsp = true,
        }
        if explicit[server_name] then
          return
        end

        -- Generic enable for everything else (yamlls, bashls, marksman, taplo…)
        vim.lsp.config(server_name, { exit_timeout = 3000 })
        vim.lsp.enable(server_name)
      end,
    },
  })
end

-- ── 4. mason-tool-installer ───────────────────────────────────────────────────
local mti_ok, mti = pcall(require, "mason-tool-installer")
if mti_ok then
  mti.setup({
    ensure_installed = mason_tools,
    auto_update = false,
    run_on_start = true,
    start_delay = 2000,
  })
end

