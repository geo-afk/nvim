-- =============================================================================
--  lua/plugins/init.lua  ·  Plugin loader
--
--  Each file in this directory is self-contained:
--    1. Declares its plugin(s) via vim.pack.add()
--    2. Runs its own setup() with pcall guards
-- =============================================================================

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

local loader = require("custom.loader")

loader.register({
  -- Core / UI foundation: needed before config.ui, statusline, and tabline draw.
  { mod = "plugins.icons", priority = "critical" },
  { mod = "plugins.colorscheme", priority = "critical" },

  -- General UI and key discovery.
  { mod = "plugins.which-key", defer = true },
  { mod = "plugins.mini-session", defer = true },
  { mod = "plugins.tint-diagnostic", defer = true },
  { mod = "plugins.smear", defer = true },
  { mod = "plugins.color-highlight", event = { "BufReadPost", "BufNewFile" } },

  -- Syntax/parsing and language affordances.
  {
    mod = "plugins.treesitter",
    event = { "BufReadPre", "BufNewFile" },
  },
  { mod = "plugins.rainbow", event = "BufReadPost", deps = { "plugins.treesitter" } },
  { mod = "plugins.ts-autotag", ft = { "html", "javascriptreact", "typescriptreact", "vue", "svelte" } },
  { mod = "plugins.lazydev", ft = "lua" },
  {
    mod = "plugins.gotools",
    ft = { "go", "gomod", "gowork", "gotmpl" },
    keys = "<leader>i",
  },
  {
    mod = "plugins.markdown",
    ft = { "markdown", "html", "yaml", "latex ", "typst " },
    -- keys = { "<leader>m" },
  },

  {
    mod = "plugins.go_debugger",
    ft = { "go", "gomod" },
    -- keys = { "<leader>Gd" },
    config = function(go_debugger)
      go_debugger.setup()
    end,
  },

  -- LSP and completion stack.
  { mod = "plugins.mason", event = { "BufReadPre", "BufNewFile" } },
  { mod = "plugins.lsp", event = { "BufReadPre", "BufNewFile" }, deps = { "plugins.mason" } },
  { mod = "plugins.snippets", event = "InsertEnter" },
  {
    mod = "plugins.completion",
    event = "InsertEnter",
    deps = { "plugins.snippets", "plugins.lazydev" },
  },

  -- Formatting / linting / VCS.
  { mod = "plugins.formatting", event = { "BufReadPre", "BufNewFile" } },
  { mod = "plugins.linting", event = { "BufReadPost", "BufWritePost" } },
  { mod = "plugins.gitsigns", event = { "BufReadPre", "BufNewFile" } },

  -- Heavy navigation: command/key stubs load the real modules on first use.
  {
    mod = "plugins.telescope",
    cmd = "Telescope",
    keys = {
      "<leader><leader>",
      "<leader>sf",
      "<leader>sg",
      "<leader>sw",
      "<leader>sd",
      "<leader>sk",
      "<leader>sh",
      "<leader>ss",
      "<leader>sr",
      "<leader>s.",
      "<leader>si",
      "<leader>sn",
      "<leader>s/",
    },
  },
  {
    mod = "plugins.flash",
    defer = true,
    deps = { "plugins.treesitter" },
  },
  {
    mod = "plugins.trouble",
    cmd = "Trouble",
    keys = { "<leader>xx", "<leader>xX", "<leader>xs", "<leader>xl", "<leader>xL", "<leader>xQ" },
  },

  -- Built-in 0.12 optional plugins.
  {
    mod = "plugins.builtin_undotree",
    cmd = "Undotree",
    keys = "<leader>uu",
  },
  {
    mod = "plugins.builtin_difftool",
    cmd = "DiffTool",
    keys = "<leader>nd",
  },
  {
    mod = "plugins.builtin_tohtml",
    cmd = "TOhtml",
  },
})

local map = vim.keymap.set
map("n", "<leader>pu", function()
  vim.pack.update()
end, { desc = "Update plugins" })

map("n", "<leader>uu", "<cmd>Undotree<CR>", { desc = "Undotree" })
map("n", "<leader>nd", "<cmd>DiffTool<CR>", { desc = "DiffTool" })
