-- =============================================================================
--  Neovim 0.12 Configuration  ·  init.lua
--  Requires: Neovim >= 0.12.0
--
--  Module load order matters:
--   1. plugins  – vim.pack declares & syncs plugins first
--   2. options  – set vim.opt values (some depend on plugin state)
--   3. keymaps  – global key bindings
--   4. autocmds – event-driven behaviour
--   5. lsp      – language-server setup
--   6. ui       – visual / UX layer (ui2, winborder, statusline …)
-- =============================================================================

-- Guard: abort with a clear message on old Neovim.
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("This config requires Neovim >= 0.12.  Current: " .. tostring(vim.version()), vim.log.levels.ERROR)
  return
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ── Loader Bootstrap ─────────────────────────────────────────────────────────
-- The custom loader owns require timing for first-frame startup, event hooks,
-- command/key stubs, and on-demand setup callbacks.
local loader = require("custom.loader")

loader.setup({
  profile = false,
  debug = false,
  defer_timeout = 100,
  idle_batch = 3,
})

loader.register({
  -- Startup spine: options, plugin declarations that shape first draw, globals.
  { mod = "config.options", priority = "critical" },
  { mod = "plugins", priority = "critical", deps = { "config.options" } },
  { mod = "config.keymaps", priority = "critical", deps = { "config.options" } },
  { mod = "config.autocmds", priority = "critical", deps = { "config.options" } },
  { mod = "config.ui", priority = "critical", deps = { "plugins.colorscheme" } },
  {
    mod = "custom.statusline",
    priority = "critical",
    deps = { "config.ui", "plugins.icons" },
    config = function(statusline)
      statusline.setup()
    end,
  },
  {
    mod = "custom.tabline",
    priority = "critical",
    deps = { "config.ui", "custom.statusline" },
    config = function(tabline)
      tabline.setup()
    end,
  },

  -- LSP/runtime services are configured shortly after startup so opening files
  -- from the explorer does not pay the setup cost synchronously.
  {
    mod = "config.lsp",
    defer = true,
    priority = "high",
    deps = { "plugins.lsp" },
    config = function(lsp)
      lsp.setup()
      lsp.setup_lsps()
    end,
  },
  {
    mod = "custom.code_action",
    event = "LspAttach",
    config = function(code_action)
      code_action.setup()
    end,
  },
  {
    mod = "custom.lsp_keymapper",
    event = "LspAttach",
    config = function(keymapper)
      keymapper.setup()
    end,
  },
  {
    mod = "custom.lightbulb",
    event = "LspAttach",
    config = function(lightbulb)
      lightbulb.setup()
    end,
  },

  -- UI tools and editing helpers.
  {
    mod = "custom.cmdline",
    defer = true,
    deps = { "config.ui" },
    config = function(cmdline)
      cmdline.setup()
    end,
  },
  {
    mod = "custom.autoclose",
    event = "BufReadPost",
    keys = {
      "<leader>aa",
      "<leader>ad",
      "<leader>ar",
      "<leader>an",
      "<leader>aa",
    },
    config = function(autoclose)
      autoclose.setup()
    end,
  },
  {
    mod = "custom.glow",
    ft = "markdown",
    cmd = { "GlowPreview", "GlowURL", "GlowTUI", "GlowTUICwd", "GlowAutoToggle", "GlowVisual" },
    config = function(glow)
      glow.setup()
    end,
  },
  {
    mod = "custom.pack_manager",
    cmd = "PackManager",
    keys = "<leader>pp",
    config = function(pack_manager)
      pack_manager.setup()
    end,
  },
  { mod = "custom.right_menu", idle = true },

  -- Project/Git, Explorer, Terminal.
  {
    mod = "custom.lazygit",
    keys = "<leader>gg",
    config = function(lazygit)
      lazygit.setup()
    end,
  },
  {
    mod = "custom.explorer",
    cmd = { "Explorer", "ExplorerReveal", "ExplorerProjects", "ExplorerProjectPin" },
    keys = "<leader>e",
    config = function(explorer)
      explorer.setup()
    end,
  },
  {
    mod = "custom.terminal_manager",
    cmd = {
      "TerminalNew",
      "TerminalProfiles",
      "TerminalProfileNew",
      "TerminalAutomation",
      "TerminalSplit",
      "TerminalHide",
      "TerminalSearch",
      "TerminalFloat",
      "TerminalPanel",
      "TerminalEnvAdd",
    },
    keys = {
      "<leader>zt",
      "<leader>z|",
      "<leader>z<",
      "<leader>z>",
      "<leader>zx",
      "<leader>zh",
      "<leader>zf",
      "<leader>zn",
      "<leader>zT",
      "<leader>zp",
      "<leader>zP",
      { "<leader>zs", mode = "x" },
    },
  },

  -- Language-specific helpers.
  {
    mod = "utils.go",
    ft = { "go", "gomod", "gowork", "gotmpl" },
    config = function(go_utils)
      go_utils.setup()
    end,
  },
  { mod = "custom.golang", ft = { "go", "gomod", "gowork", "gotmpl" }, deps = { "utils.go" } },
})

-- Load the plugin registry before bootstrap so plugin-level event/cmd/key specs
-- are visible when the loader wires triggers.
loader.load("plugins")

local ok, err = pcall(function()
  loader.bootstrap()
end)

if not ok then
  vim.notify("Error in loader bootstrap: " .. tostring(err), vim.log.levels.ERROR)
end
