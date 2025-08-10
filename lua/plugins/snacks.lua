return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = {
      enabled = true,
      size = 1.5 * 1024 * 1024, -- 1.5MB
      setup = function()
        vim.cmd [[NoMatchParen]]
        vim.opt_local.foldmethod = 'manual'
        vim.opt_local.spell = false
        vim.opt_local.swapfile = false
        vim.opt_local.undofile = false
        vim.opt_local.breakindent = false
        vim.opt_local.colorcolumn = ''
        vim.opt_local.statuscolumn = ''
        vim.opt_local.signcolumn = 'no'
      end,
    },
    animate = {
      enabled = true,

      -- Optional: fine-tune animation types
      -- You can set false for animations you don’t want
      scroll = { enabled = true, duration = 200, fps = 60 },
      cursor = { enabled = true, duration = 100, fps = 60 },
      resize = { enabled = true, duration = 150, fps = 60 },

      -- Easing functions: "linear", "inOutQuad", "inOutCubic", etc.
      easing = 'inOutQuad',
    },
    indent = {
      enabled = true,
    },
    explorer = {
      enabled = true,
      replace_netrw = true,
    },
    lazygit = {
      enabled = true,
      configure = true,
    },
    git = {
      enabled = true,
    },
    terminal = {
      enabled = true,
      win = {
        style = 'terminal',
      },
    },
    input = {
      enabled = true,
      win = {
        relative = 'cursor',
        row = -3,
        col = 0,
      },
    },
    picker = {
      enabled = true,
      win = {
        input = {
          keys = {
            ['<C-j>'] = { 'move_down', mode = { 'i', 'n' } },
            ['<C-k>'] = { 'move_up', mode = { 'i', 'n' } },
          },
        },
      },
    },
  },
  keys = {
    -- Explorer
    {
      '<leader>e',
      function()
        Snacks.explorer()
      end,
      desc = 'Explorer',
    },
    {
      '<leader>E',
      function()
        Snacks.explorer.open()
      end,
      desc = 'Explorer (cwd)',
    },

    -- Git
    {
      '<leader>gg',
      function()
        Snacks.lazygit()
      end,
      desc = 'Lazygit',
    },
    {
      '<leader>gb',
      function()
        Snacks.git.blame_line()
      end,
      desc = 'Git Blame Line',
    },
    {
      '<leader>gB',
      function()
        Snacks.gitbrowse()
      end,
      desc = 'Git Browse',
    },
    {
      '<leader>gf',
      function()
        Snacks.lazygit.log_file()
      end,
      desc = 'Lazygit Current File History',
    },
    {
      '<leader>gl',
      function()
        Snacks.lazygit.log()
      end,
      desc = 'Lazygit Log (cwd)',
    },

    -- Terminal
    {
      '<leader>t',
      function()
        Snacks.terminal()
      end,
      desc = 'Toggle Terminal',
    },
    {
      '<c-/>',
      function()
        Snacks.terminal()
      end,
      desc = 'Toggle Terminal',
    },
    {
      '<c-_>',
      function()
        Snacks.terminal()
      end,
      desc = 'which_key_ignore',
    },

    -- Picker
    {
      '<leader>ff',
      function()
        Snacks.picker.files()
      end,
      desc = 'Find Files',
    },
    {
      '<leader>fg',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Grep',
    },
    {
      '<leader>fb',
      function()
        Snacks.picker.buffers()
      end,
      desc = 'Buffers',
    },
    {
      '<leader>fh',
      function()
        Snacks.picker.help()
      end,
      desc = 'Help',
    },
    {
      '<leader>fr',
      function()
        Snacks.picker.recent()
      end,
      desc = 'Recent Files',
    },
    {
      '<leader>fc',
      function()
        Snacks.picker.command_history()
      end,
      desc = 'Command History',
    },
    {
      '<leader>fs',
      function()
        Snacks.picker.search_history()
      end,
      desc = 'Search History',
    },
  },
}
