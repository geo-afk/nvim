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
  { mod = "plugins.color-highlight", defer = true },

  -- Syntax/parsing and language affordances.
  {
    mod = "plugins.treesitter",
    ft = {
      "angular",
      "css",
      "go",
      "gomod",
      "gowork",
      "gotmpl",
      "html",
      "javascript",
      "javascriptreact",
      "json",
      "jsonc",
      "lua",
      "markdown",
      "query",
      "regex",
      "scss",
      "sql",
      "toml",
      "typescript",
      "typescriptreact",
      "vim",
    },
  },
  { mod = "plugins.rainbow", defer = true, deps = { "plugins.treesitter" } },
  { mod = "plugins.ts-autotag", ft = { "html", "javascriptreact", "typescriptreact", "vue", "svelte" } },
  { mod = "plugins.lazydev", ft = "lua" },
  {
    mod = "plugins.gotools",
    ft = { "go", "gomod", "gowork", "gotmpl" },
    keys = "<leader>i",
  },
  {
    mod = "plugins.markdown",
    ft = { "markdown", "html", "yaml", "latex", "typst" },
    -- keys = { "<leader>m" },
  },
  -- LSP and completion stack.
  {
    mod = "plugins.mason",
    cmd = "Mason",
    keys = { { "<leader>pm", desc = "Mason UI" } },
  },
  { mod = "plugins.lsp", defer = true, priority = "high" },
  { mod = "plugins.snippets", event = "InsertEnter" },
  {
    mod = "plugins.completion",
    event = "InsertEnter",
    deps = { "plugins.snippets", "plugins.lazydev" },
  },

  -- Formatting / linting / VCS.
  { mod = "plugins.formatting", defer = true },
  { mod = "plugins.linting", defer = true },
  { mod = "plugins.gitsigns", idle = true },

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

  -- Tasks and Debugging.
  {
    mod = "plugins.overseer",
    cond = function()
      return vim.fs.root(0, { "go.mod", "package.json", "angular.json", ".git", "Makefile" }) ~= nil
    end,
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
    cond = function()
      return vim.fs.root(0, { "go.mod", "package.json", "angular.json", ".git" }) ~= nil
    end,
    cmd = { "DapContinue", "DapToggleBreakpoint", "DapStepOver", "DapStepInto", "DapStepOut" },
    keys = {
      { "<leader>dc", desc = "Continue" },
      { "<leader>dC", desc = "Run to cursor" },
      { "<leader>dq", desc = "Terminate" },
      { "<leader>dr", desc = "Restart" },
      { "<leader>dp", desc = "Pause" },
      { "<leader>dl", desc = "Run last" },
      { "<leader>dn", desc = "Step over" },
      { "<leader>di", desc = "Step into" },
      { "<leader>do", desc = "Step out" },
      { "<leader>db", desc = "Step back" },
      { "<leader>dB", desc = "Toggle breakpoint" },
      { "<leader>dX", desc = "Clear all" },
      { "<leader>dh", desc = "Hover variable" },
      { "<leader>du", desc = "Toggle UI" },
      { "<leader>de", desc = "Eval expr" },
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
