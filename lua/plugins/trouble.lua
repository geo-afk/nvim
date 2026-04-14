-- =============================================================================
--  plugins/trouble.lua  ·  trouble.nvim  (diagnostic / quickfix panel)
-- =============================================================================

vim.pack.add({ { src = "https://github.com/folke/trouble.nvim" } })

local ok, trouble = pcall(require, "trouble")
if not ok then return end

trouble.setup({})
