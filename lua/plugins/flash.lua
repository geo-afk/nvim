-- =============================================================================
--  plugins/flash.lua  ·  flash.nvim  (jump / search / treesitter navigation)
-- =============================================================================

vim.pack.add({ { src = "https://github.com/folke/flash.nvim" } })

local ok, flash = pcall(require, "flash")
if not ok then
  return
end

-- Optional cinnamon.nvim smooth-scroll integration
local cinnamon_ok, cinnamon = pcall(require, "cinnamon")
if cinnamon_ok then
  local jump = require("flash.jump")
  flash.setup({
    action = function(match, state)
      cinnamon.scroll(function()
        jump.jump(match, state)
        jump.on_jump(state)
      end)
    end,
  })
else
  flash.setup()
end

local map = vim.keymap.set
-- stylua: ignore start
map({ "n", "x", "o" }, "s",     function() flash.jump() end,               { desc = "Flash" })
map({ "n", "x", "o" }, "S",     function() flash.treesitter() end,         { desc = "Flash Treesitter" })
map("o",               "r",     function() flash.remote() end,             { desc = "Remote Flash" })
map({ "o", "x" },     "R",     function() flash.treesitter_search() end,  { desc = "Treesitter Search" })
map("c",               "<C-s>", function() flash.toggle() end,             { desc = "Toggle Flash Search" })
-- stylua: ignore end
