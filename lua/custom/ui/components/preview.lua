local list = require("custom.ui.components.list")

local M = {}

function M.open(opts)
  opts = opts or {}
  opts.enter = opts.enter == true
  opts.filetype = opts.filetype or "custom_ui_preview"
  opts.title = opts.title or " Preview "
  opts.float_options = vim.tbl_extend("force", { wrap = true, cursorline = false }, opts.float_options or {})
  return list.open(opts)
end

return M
