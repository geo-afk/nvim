-- =============================================================================
--  plugins/rainbow.lua  ·  rainbow-delimiters.nvim
-- =============================================================================
vim.pack.add({ { src = "https://github.com/HiPhish/rainbow-delimiters.nvim" } })

local ok, rainbow = pcall(require, "rainbow-delimiters.setup")
if not ok then
  return
end

rainbow.setup({
  highlight = {
    "RainbowDelimiterRed",
    "RainbowDelimiterYellow",
    "RainbowDelimiterBlue",
    "RainbowDelimiterOrange",
    "RainbowDelimiterGreen",
    "RainbowDelimiterViolet",
    "RainbowDelimiterCyan",
  },
})
