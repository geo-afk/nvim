-- =============================================================================
--  plugins/treesitter.lua  ·  nvim-treesitter
-- =============================================================================

vim.pack.add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    version = "master",
    build = ":tsupdate",
  },
})

local ok, ts = pcall(require, "nvim-treesitter.config")
if not ok then
  vim.print("Not OK")
  vim.notify("Not oK", vim.log.levels.DEBUG)
  return
end

ts.setup({
  ensure_installed = {
    "lua",
    "typescript",
    "tsx",
    "javascript",
    "go",
    "json",
    "jsonc",
    "html",
    "css",
    "scss",
    "markdown",
    "markdown_inline",
    "regex",
    "vim",
    "vimdoc",
    "query",
    "toml",
    "sql",
    "angular",
  },
  auto_install = true,
  highlight = { enable = true, additional_vim_regex_highlighting = false },
  indent = { enable = true, disable = { "ruby" } },
  install_dir = vim.fn.stdpath("data") .. "/site",

  -- [0.12] incremental_selection also powered by lsp selectionrange (v_an/v_in)
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
})

vim.api.nvim_create_autocmd("PackChanged", {
  desc = "handle nvim-treesitter updates",
  group = vim.api.nvim_create_augroup("nvim-treesitter-pack-changed-update-handler", { clear = true }),
  callback = function(event)
    if event.data.kind == "update" and event.data.spec.name == "nvim-treesitter" then
      vim.notify("nvim-treesitter updated, running tsupdate...", vim.log.levels.INFO)
      ---@diagnostic disable-next-line: param-type-mismatch
      local okay = pcall(vim.cmd, "tsupdate")
      if okay then
        vim.notify("tsupdate completed successfully!", vim.log.levels.INFO)
      else
        vim.notify("tsupdate command not available yet, skipping", vim.log.levels.WARN)
      end
    end
  end,
})
