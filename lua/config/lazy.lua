-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.neovide")
-- require 'utils.angular'

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
    { import = "plugins.lsp" },
    -- { import = "plugins.lsp.blink" },
    { import = "plugins.ui" },
    { import = "plugins.tools" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false },
  change_detection = {
    notify = false,
  },

  -- Performance: disable built-in Neovim plugins we don't use
  -- This shaves a few ms off startup time
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },

  ui = {
    border = "rounded",
    icons = {
      cmd = "⌘",
      config = "🛠",
      event = "📅",
      ft = "📂",
      init = "⚙",
      keys = "🗝",
      plugin = "🔌",
      runtime = "💻",
      source = "📄",
      start = "🚀",
      task = "📌",
    },
  },
})

require("custom.explorer").setup()
require("custom.statusline").setup()
require("custom.tabline").setup()
require("custom.lsp_keymapper").setup()
-- require('custom.notifier').setup()
require("custom.autoclose").setup()
require("custom.scratch").setup({
  notes_dir = "~/Downloads/Notes", -- optional overrides
  filename = "scratch.md",
  commit_message = "chore: update notes",
  float = {
    percent_width = 0.7,
    percent_height = 0.6,
  },
})

require("custom.glow").setup({
  style = "auto", -- or "dark" / "light"
  width = 100,
})

local codelens = require("custom.codelens")

-- Setup with settings
codelens.setup({
  -- codelens = true, -- Enable by default
})

require("custom.cmdline").setup()

-- Later you can toggl
-- codelens.set_enabled(false) -- Disable
-- codelens.set_enabled(true) -- Re-enable

-- Manually refresh
-- codelens.refresh_all()

-- Clear all
-- codelens.clear_all()

-- Run action (bound to :LspCodeLensRun)
-- codelens.run_action()
