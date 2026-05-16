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

  -- Syntax / parsing (Core essentials)
  require("plugins.treesitter")
  require("plugins.rainbow")

  -- LSP toolchain
  require("plugins.mason")
  require("plugins.lsp")
  require("plugins.completion")
  require("plugins.snippets")

  -- Formatting / linting
  require("plugins.formatting")
  require("plugins.linting")

  -- Navigation & UI (Basic)
  require("plugins.tint-diagnostic")
  require("plugins.smear")
  require("plugins.color-highlight")

  -- ── Conditional / Lazy Loading ─────────────────────────────────────────────

  -- Language Specific
  Loader.on_filetype("lua", function()
    require("plugins.lazydev")
  end)

  Loader.on_filetype("go", function()
    require("plugins.go_debugger").setup()
    require("plugins.gotools")
  end)

  Loader.on_filetype({
    "html",
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
    "vue",
    "svelte",
    "xml",
  }, function()
    require("plugins.ts-autotag")
  end)

  -- Git signs: only on real files
  Loader.on_event({ "BufReadPre", "BufNewFile" }, function()
    require("plugins.gitsigns")
  end)

  -- Heavy Navigation: load on keypress
  Loader.on_keys({ "<leader>s", "<leader><leader>" }, function()
    require("plugins.telescope")
  end)

  Loader.on_keys({ "s", "S" }, function()
    require("plugins.flash")
  end)

  Loader.on_keys({ "<leader>x" }, function()
    require("plugins.trouble")
  end)

  -- Activate built-in 0.12 optional plugins
  for _, pkg in ipairs({ "nvim.undotree", "nvim.difftool", "nvim.tohtml" }) do
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "packadd " .. pkg)
  end
end)

local map = vim.keymap.set
map("n", "<leader>pu", function()
  vim.pack.update()
end, { desc = "Update plugins" })

map("n", "<leader>uu", "<cmd>Undotree<CR>", { desc = "Undotree" })
map("n", "<leader>nd", "<cmd>DiffTool<CR>", { desc = "DiffTool" })
