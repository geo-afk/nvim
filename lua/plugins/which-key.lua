-- =============================================================================
--  plugins/which-key.lua  ·  which-key.nvim
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/which-key.nvim" } })

local ok, wk = pcall(require, "which-key")
if not ok then return end

wk.setup({
  preset    = "helix",
  delay     = 0,
  defaults  = {},
  show_help = true,
  spec = {
    { "<leader>e", icon = { icon = "⟟",  hl = "MiniIconsBrown"  }, group = "File Explorer" },
    { "<leader>/", icon = { icon = "∷",  hl = "MiniIconsYellow" }, group = "Find In Current Buffer" },
    { "<leader>x", icon = { icon = "!",  hl = "MiniIconsRed"    }, group = "Diagnostics/Quickfix" },
    { "<leader>d", icon = { icon = "⨁",  hl = "MiniIconsRed"    }, group = "LSP: DEV-SERVER" },
    { "<leader>q", icon = { icon = "☰",  hl = "MiniIconsGrey"   }, group = "Quick-Fix List" },
    { "<leader>p", icon = { icon = "≡",  hl = "MiniIconsGreen"  }, group = "Plugins/UI" },
    { "<leader>w", icon = { icon = "⟲",  hl = "MiniIconsBlue"   }, group = "Session" },
    { "<leader>r", icon = { icon = "⟲",  hl = "MiniIconsOrange" }, group = "Replace" },
    { "<leader>b", icon = { icon = "▦",  hl = "MiniIconsCyan"   }, group = "Buffer" },
    { "<leader>s", icon = { icon = "⌕",  hl = "MiniIconsYellow" }, group = "Search" },
    { "<leader>m", icon = { icon = "•",  hl = "MiniIconsOrange" }, group = "Marks" },
    { "<leader>i", icon = { icon = "i",  hl = "MiniIconsBlue"   }, group = "Info" },
    { "<leader>c", icon = { icon = "λ",  hl = "MiniIconsGreen"  }, group = "Code" },
    { "<leader>u", icon = { icon = "↩",  hl = "MiniIconsPurple" }, group = "Undo" },
    { "<leader>v", icon = { icon = "⎇",  hl = "MiniIconsGreen"  }, group = "Git" },
    { "<leader>t", icon = { icon = "▸",  hl = "MiniIconsGrey"   }, group = "Terminal" },
    { "m",         icon = { icon = "◆",  hl = "MiniIconsOrange" }, group = "Marks" },
    { "g",         icon = { icon = "➜",  hl = "MiniIconsBlue"   }, group = "Goto" },
  },
})

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
