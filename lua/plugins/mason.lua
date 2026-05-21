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

-- vim.lsp server name -> Mason package name
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
  codebook = "codebook",
  marksman = "marksman",
  jsonls = "json-lsp",
}

local mason_tools = {
  "gofumpt",
  "goimports",
  "golines",
  "staticcheck",
  "gomodifytags",
  "biome",
  "prettierd",
  "stylua",
  "ruff",
}

local ensure_installed = {}
for _, pkg in pairs(lsp_to_mason) do
  ensure_installed[#ensure_installed + 1] = pkg
end
vim.list_extend(ensure_installed, mason_tools)

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

vim.keymap.set("n", "<leader>pm", "<cmd>Mason<CR>", { desc = "Mason UI" })

local mlsp_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
if mlsp_ok then
  mason_lspconfig.setup({
    handlers = {
      function(server_name)
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

        vim.lsp.config(server_name, { exit_timeout = 3000 })
        vim.lsp.enable(server_name)
      end,
    },
  })
end

local mti_ok, mti = pcall(require, "mason-tool-installer")
if mti_ok then
  mti.setup({
    ensure_installed = ensure_installed,
    auto_update = false,
    run_on_start = true,
    start_delay = 2000,
  })
end
