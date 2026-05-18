-- ~/.config/nvim/lua/plugins/mini-sessions.lua

-- Install plugin
vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.sessions" },
})

-- Better session options
vim.o.sessionoptions = "buffers,curdir,folds,globals,help,skiprtp,tabpages,terminal,winsize"

-- Setup
require("mini.sessions").setup({
  -- Automatically load the latest session
  autoread = true,

  -- Automatically save current session on exit
  autowrite = true,

  -- Directory for global sessions
  directory = vim.fn.stdpath("state") .. "/sessions",

  -- Local session filename
  file = "Session.vim",

  -- Force behavior
  force = {
    read = false,
    write = true,
    delete = false,
  },

  -- Optional hooks
  hooks = {
    pre = {
      read = function()
        vim.notify("Loading session...")
      end,

      write = function()
        vim.notify("Saving session...")
      end,

      delete = nil,
    },

    post = {
      read = function()
        vim.notify("Session loaded")
      end,

      write = function()
        vim.notify("Session saved")
      end,

      delete = nil,
    },
  },

  -- Verbose messages
  verbose = {
    read = true,
    write = true,
    delete = true,
  },
})

----------------------------------------------------------------------
-- Keymaps
----------------------------------------------------------------------

local map = vim.keymap.set

-- Write session
map("n", "<leader>kw", function()
  local session_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")

  MiniSessions.write(session_name)
end, { desc = "Write session" })

-- Select session
map("n", "<leader>ks", function()
  MiniSessions.select()
end, { desc = "Select session" })

-- Read latest session
map("n", "<leader>kl", function()
  local session = MiniSessions.get_latest()
  if session then
    MiniSessions.read(session)
  end
end, { desc = "Load latest session" })

-- Delete session
map("n", "<leader>kd", function()
  MiniSessions.select("delete")
end, { desc = "Delete session" })

-- Restart Neovim with current session
map("n", "<leader>kr", function()
  MiniSessions.restart()
end, { desc = "Restart with session" })
