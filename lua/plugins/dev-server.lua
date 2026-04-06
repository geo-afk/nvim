-- =============================================================================
--  plugins/dev-server.lua  ·  dev-server.nvim
--
--  Manages development servers (Angular, Go air, etc.) inside Neovim.
-- =============================================================================

vim.pack.add({ { src = "https://github.com/geo-afk/dev-server" } })

local ok, dev_server = pcall(require, "dev-server")
if not ok then return end

dev_server.setup({
  window = {
    type     = "split",
    position = "botright",
    size     = 15,
  },
  keymaps = {
    toggle  = "<leader>dt",
    restart = "<leader>dr",
    stop    = "<leader>ds",
    status  = "<leader>dS",
  },
  auto_start    = false,
  notifications = {
    enabled = true,
    level   = {
      start = vim.log.levels.INFO,
      stop  = vim.log.levels.INFO,
      error = vim.log.levels.ERROR,
    },
  },
  servers = {
    angular = {
      cmd    = "ng serve",
      detect = { marker = "angular.json" },
      window = { type = "split", position = "botright", size = 20 },
    },
    -- Uncomment and adapt for other stacks:
    -- go = { cmd = "air .", window = { type = "split", position = "botright", size = 20 } },
    -- vite = { cmd = "npm run dev", detect = { marker = "vite.config.ts" } },
  },
})

vim.keymap.set("n", "<leader>gi", "<cmd>DevServerStatus<CR>", { desc = "Dev server: show all" })
