-- =============================================================================
--  plugins/formatting.lua  ·  conform.nvim
-- =============================================================================

vim.pack.add({ { src = "https://github.com/stevearc/conform.nvim" } })

local ok, conform = pcall(require, "conform")
if not ok then
  return
end

conform.setup({
  notify_on_error = true,
  log_level = vim.log.levels.WARN,

  format_on_save = function(bufnr)
    -- Disable format-on-save for C/C++ (clangd formatting can be opinionated)
    local disable_ft = { c = true, cpp = true }
    if disable_ft[vim.bo[bufnr].filetype] then
      return nil
    end
    return { timeout_ms = 1500, lsp_format = "fallback" }
  end,

  formatters_by_ft = {
    lua = { "stylua" },
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    typescriptreact = { "prettierd" },
    javascriptreact = { "prettierd" },
    go = { "gofumpt", "goimports", "golines" },
    sql = { "sleek" },
    css = { "prettierd" },
    html = { "prettierd" },
    json = { "prettierd" },
    jsonc = { "prettierd" },
    yaml = { "prettierd" },
    markdown = { "prettierd" },
    python = { "ruff_format" },
    sh = { "shfmt" },
    bash = { "shfmt" },
  },

  formatters = {
    sleek = {
      command = "sleek",
      args = { "--uppercase=true", "--indent-spaces=3", "--trailing-newline=false" },
      stdin = true,
    },
    ruff_format = {
      command = "ruff",
      args = { "format", "--stdin-filename", "$FILENAME", "-" },
      stdin = true,
    },
  },
})
