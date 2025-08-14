local M = {}

M.keys = {
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
}

return M
