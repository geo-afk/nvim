-- =============================================================================
--  lua/plugins/init.lua  ·  Plugin loader
--
--  Each file in this directory is self-contained:
--    1. Declares its plugin(s) via vim.pack.add()
--    2. Runs its own setup() with pcall guards
-- =============================================================================

local Loader = require("custom.loader")

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
-- These must load immediately for visual consistency.
Loader.now(function()
  require("plugins.icons") -- nvim-web-devicons
  require("plugins.colorscheme") -- tokyonight
end)

-- ── Deferred Loading ─────────────────────────────────────────────────────────
-- Everything else is scheduled to load after the initial UI loop to speed up
-- the first frame and reduce startup blocking.
Loader.later(function()
  -- Keybinding helper
  require("plugins.which-key")

  -- Syntax / parsing
  require("plugins.treesitter")
  require("plugins.rainbow")
  require("plugins.ts-autotag")

  -- LSP toolchain
  require("plugins.mason")
  require("plugins.lsp")
  require("plugins.lazydev")
  require("plugins.completion")
  require("plugins.snippets")

  -- Formatting / linting
  require("plugins.formatting")
  require("plugins.linting")

  -- Diagnostics / navigation
  require("plugins.trouble")
  require("plugins.telescope")
  require("plugins.flash")

  -- Git
  require("plugins.gitsigns")

  -- Eye candy
  require("plugins.smear")
  require("plugins.color-highlight")

  -- Dev tools
  require("plugins.dev-server")

  -- Activate built-in 0.12 optional plugins
  for _, pkg in ipairs({ "nvim.undotree", "nvim.difftool", "nvim.tohtml" }) do
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "packadd " .. pkg)
  end
end)
