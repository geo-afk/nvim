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
  {
    mod = "plugins.mini-session",
    keys = {
      { "<leader>ks", desc = "Select session" },
      { "<leader>kw", desc = "Write session" },
      { "<leader>kl", desc = "Load latest" },
      { "<leader>kd", desc = "Delete session" },
      { "<leader>kr", desc = "Restart Neovim" },
    },
  },
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

  -- {
  --   mod = "plugins.go_debugger",
  --   ft = { "go", "gomod" },
  --   -- keys = { "<leader>Gd" },
  --   config = function(go_debugger)
  --     go_debugger.setup()
  --   end,
  -- },
  --
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
      { "<leader><leader>", desc = "Fuzzy buffer" },
      { "<leader>sf", desc = "Find files" },
      { "<leader>sg", desc = "Live grep" },
      { "<leader>sw", desc = "Grep word" },
      { "<leader>sd", desc = "Diagnostics" },
      { "<leader>sk", desc = "Keymaps" },
      { "<leader>sh", desc = "Help tags" },
      { "<leader>ss", desc = "Symbols" },
      { "<leader>sr", desc = "Resume" },
      { "<leader>s.", desc = "Recent files" },
      { "<leader>si", desc = "Hidden files" },
      { "<leader>sn", desc = "Neovim config" },
      { "<leader>s/", desc = "Grep buffer" },
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
    keys = {
      { "<leader>xx", desc = "Diagnostics" },
      { "<leader>xX", desc = "Buffer Diag" },
      { "<leader>xs", desc = "Symbols" },
      { "<leader>xl", desc = "LSP Refs" },
      { "<leader>xL", desc = "Loclist" },
      { "<leader>xQ", desc = "Quickfix" },
    },
  },

  -- Tasks and Debugging.
  {
    mod = "plugins.overseer",
    ft = { "go", "javascript", "typescript", "javascriptreact", "typescriptreact", "html", "css", "scss", "make" },
    cmd = { "OverseerRun", "OverseerToggle", "OverseerBuild" },
    keys = {
      { "<leader>or", desc = "Run task" },
      { "<leader>ot", desc = "Toggle panel" },
      { "<leader>oo", desc = "Open output" },
      { "<leader>ol", desc = "Rerun last" },
      { "<leader>ob", desc = "Task builder" },
      { "<leader>os", desc = "Save bundle" },
      { "<leader>oL", desc = "Load bundle" },
      { "<leader>oQ", desc = "Quickfix last" },
    },
  },

  {
    mod = "plugins.dap",
    ft = { "go", "javascript", "typescript", "javascriptreact", "typescriptreact", "html" },
    cmd = { "DapContinue", "DapToggleBreakpoint", "DapStepOver", "DapStepInto", "DapStepOut" },
    keys = {
      { "<leader>Dc", desc = "Continue" },
      { "<leader>DC", desc = "Run to cursor" },
      { "<leader>Dq", desc = "Terminate" },
      { "<leader>Dr", desc = "Restart" },
      { "<leader>Dp", desc = "Pause" },
      { "<leader>Dl", desc = "Run last" },
      { "<leader>Dn", desc = "Step over" },
      { "<leader>Di", desc = "Step into" },
      { "<leader>Do", desc = "Step out" },
      { "<leader>Db", desc = "Step back" },
      { "<leader>DB", desc = "Toggle breakpoint" },
      { "<leader>DX", desc = "Clear all" },
      { "<leader>Dh", desc = "Hover variable" },
      { "<leader>Du", desc = "Toggle UI" },
      { "<leader>De", desc = "Eval expr" },
    },
    deps = { "plugins.overseer" },
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
