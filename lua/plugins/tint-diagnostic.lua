vim.pack.add({
  { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" },
})

local ok, tiny = pcall(require, "tiny-inline-diagnostic")
if not ok then
  return
end

-- Disable default virtual text (REQUIRED)
-- vim.diagnostic.config({
--   virtual_text = false,
--   signs = true,
--   underline = true,
--   update_in_insert = false,
--   severity_sort = true,
-- })

tiny.setup({
  preset = "modern",

  transparent_bg = false,
  transparent_cursorline = true,

  hi = {
    error = "DiagnosticError",
    warn = "DiagnosticWarn",
    info = "DiagnosticInfo",
    hint = "DiagnosticHint",

    virt_texts = {
      priority = 2048, -- ensures it wins over other virtual text (git blame, etc.)
    },

    severity = {
      vim.diagnostic.severity.ERROR,
      vim.diagnostic.severity.WARN,
      -- uncomment if you want more verbosity:
      -- vim.diagnostic.severity.INFO,
      -- vim.diagnostic.severity.HINT,
    },
  },

  options = {
    show_source = {
      enabled = true,
    },
    multilines = {
      enabled = true,
    },
    add_messages = {
      display_count = true,
    },
  },
})
