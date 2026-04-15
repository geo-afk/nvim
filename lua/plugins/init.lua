-- =============================================================================
--  lua/plugins/init.lua  ·  Plugin loader
--
--  Each file in this directory is self-contained:
--    1. Declares its plugin(s) via vim.pack.add()
--    2. Runs its own setup() with pcall guards
--
--  Order matters: icons → colorscheme → which-key → treesitter
--              → mason → lsp → completion → snippets → …
-- =============================================================================

local function load(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    vim.notify("plugins: failed to load " .. mod .. "\n" .. err, vim.log.levels.ERROR)
  end
end

-- Build hooks (must be registered before vim.pack.add)
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("pack_changed", { clear = true }),
  callback = function(ev)
    if ev.data.kind == "delete" then
      return
    end
    local name = ev.data.spec.name
    if name == "nvim-treesitter" then
      pcall(function()
        vim.cmd("TSUpdate")
      end)
    elseif name == "mason.nvim" then
      pcall(function()
        vim.cmd("MasonUpdate")
      end)
    end
  end,
})

-- ── Core / UI foundation ─────────────────────────────────────────────────────
load("plugins.icons") -- nvim-web-devicons
load("plugins.colorscheme") -- tokyonight

-- ── Keybinding helper (loaded early so other plugins can register groups) ────
load("plugins.which-key")

-- ── Syntax / parsing ─────────────────────────────────────────────────────────
load("plugins.treesitter")
load("plugins.rainbow") -- rainbow-delimiters
load("plugins.ts-autotag") -- auto close/rename HTML tags

-- ── LSP toolchain ────────────────────────────────────────────────────────────
load("plugins.mason") -- Mason installer + tool management
load("plugins.lsp") -- nvim-lspconfig + LspAttach wiring
load("plugins.lazydev") -- Lua/Neovim type annotations
load("plugins.completion") -- blink.cmp
load("plugins.snippets") -- LuaSnip + friendly-snippets

-- ── Formatting / linting ─────────────────────────────────────────────────────
load("plugins.formatting") -- conform.nvim
load("plugins.linting") -- nvim-lint

-- ── Diagnostics / navigation ─────────────────────────────────────────────────
load("plugins.trouble") -- trouble.nvim
load("plugins.telescope") -- telescope + fzf-native
load("plugins.flash") -- flash.nvim (jump / search)

-- ── Git ───────────────────────────────────────────────────────────────────────
load("plugins.gitsigns") -- gutter signs + hunk operations

-- ── Eye candy ────────────────────────────────────────────────────────────────
load("plugins.smear") -- smear-cursor
load("plugins.color-highlight") -- inline colour swatches

-- ── Dev tools ────────────────────────────────────────────────────────────────
load("plugins.dev-server") -- dev-server.nvim

-- ── Activate built-in 0.12 optional plugins ──────────────────────────────────
for _, pkg in ipairs({ "nvim.undotree", "nvim.difftool", "nvim.tohtml" }) do
  ---@diagnostic disable-next-line: param-type-mismatch
  pcall(vim.cmd, "packadd " .. pkg)
end
