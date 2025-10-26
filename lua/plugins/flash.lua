return {
  'folke/flash.nvim',
  event = 'VeryLazy',

  config = function()
    local ok, cinnamon = pcall(require, 'cinnamon')
    local flash = require 'flash'

    if ok then
      local jump = require 'flash.jump'
      flash.setup {
        action = function(match, state)
          cinnamon.scroll(function()
            jump.jump(match, state)
            jump.on_jump(state)
          end)
        end,
      }
    else
      flash.setup() -- fallback if cinnamon not loaded
    end
  end,

  -- stylua: ignore
  keys = {
    { "s",  mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
    { "S",  mode = { "n", "x", "o" }, function() require("flash").treesitter() end,       desc = "Flash Treesitter" },
    { "r",  mode = "o",               function() require("flash").remote() end,           desc = "Remote Flash" },
    { "R",  mode = { "o", "x" },      function() require("flash").treesitter_search() end,desc = "Treesitter Search" },
    { "<C-s>", mode = "c",            function() require("flash").toggle() end,           desc = "Toggle Flash Search" },
  },
}
