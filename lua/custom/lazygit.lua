-- plugins/lazygit.lua
-- Requires custom.float_term.term — API is unchanged (setup + create_terminal).

local ok, term = pcall(require, "custom.float_term.term")
if not ok then
  vim.notify("lazygit: custom.float_term.term not found – check lua/custom/float_term/term.lua", vim.log.levels.WARN)
  return
end

local M = {}

function M.setup()
  term.setup({
    width_ratio = 0.85,
    height_ratio = 0.85,
    border = "rounded",
    title = " LazyGit ",
  })
end

return M
