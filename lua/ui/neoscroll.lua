return {
  "karb94/neoscroll.nvim",
  event = "VeryLazy",
  config = function()
    require("neoscroll").setup({
      -- Use defaults, with minimal tweaks
      hide_cursor = true,
      stop_eof = false, -- allow scrolling past EOF for smooth feel
      respect_scrolloff = true, -- follow scrolloff
      cursor_scrolls_alone = true,
      performance_mode = false, -- keep animations
    })

    local neoscroll = require("neoscroll")
    local keymap = {
      -- Basic smooth scrolling
      ["<C-u>"] = function()
        neoscroll.ctrl_u({ duration = 251 })
      end,
      ["<C-d>"] = function()
        neoscroll.ctrl_d({ duration = 251 })
      end,
      ["<C-b>"] = function()
        neoscroll.ctrl_b({ duration = 401 })
      end,
      ["<C-f>"] = function()
        neoscroll.ctrl_f({ duration = 401 })
      end,

      -- Scroll up/down with Shift + Arrow
      ["<S-Up>"] = function()
        neoscroll.scroll(-4, { duration = 100 })
      end,
      ["<S-Down>"] = function()
        neoscroll.scroll(6, { duration = 100 })
      end,
    }

    -- Apply key mappings in normal, visual, and select modes
    local modes = { "n", "v", "x" }
    for key, func in pairs(keymap) do
      vim.keymap.set(modes, key, func)
    end
  end,
}
