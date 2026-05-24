local M = {}

M.defaults = {
  global = true,
  transparent = true,
  animation = {
    enabled = true,
    interval = 45,
    steps = 5,
  },
  separators = {
    wide = " │ ",
    compact = " ",
    sharp = "▌",
  },
  density = {
    target_padding = 2,
    left_bias = 0.58,
  },
  theme = {
    project_aware = true,
    language_aware = true,
    accent_scope = "statusline",
  },
  sections = {
    { side = "left", comp = "mode", priority = 100, required = true },
    { side = "left", comp = "file", priority = 95, required = true },
    { side = "left", comp = "git", priority = 70, required = false },
    { side = "right", comp = "lsp", priority = 65, required = false },
    { side = "right", comp = "system", priority = 25, required = false },
    { side = "right", comp = "cursor", priority = 90, required = true },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  return M.options
end

return M
