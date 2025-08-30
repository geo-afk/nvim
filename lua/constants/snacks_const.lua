local M = {}

local uv = vim.uv or vim.loop

-- Find git root
function M.find_git_root(path)
  local current = path or vim.fn.getcwd()
  while current ~= '/' do
    if vim.fn.isdirectory(current .. '/.git') == 1 then
      return current
    end
    current = vim.fn.fnamemodify(current, ':h')
  end
  return nil
end

-- Find project root manually
local function get_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  path = vim.fs.dirname(path)

  -- 1. Try LSP root
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  for _, client in ipairs(clients) do
    if client.config and client.config.root_dir then
      return vim.fs.normalize(client.config.root_dir)
    end
  end

  -- 2. Try `.git` parent
  local git_root = vim.fs.find('.git', { path = path, upward = true })[1]
  if git_root then
    return vim.fs.normalize(vim.fs.dirname(git_root))
  end

  -- 3. Fallback to cwd
  return vim.fs.normalize(uv.cwd() or '.')
end

M.actions = {
  toggle_cwd = function(p)
    local root = get_root(p.input.filter.current_buf)
    local cwd = vim.fs.normalize(uv.cwd() or '.')
    local current = p:cwd()
    p:set_cwd(current == root and cwd or root)
    p:find()
  end,
}

M.keys = {
  -- Explorer
  {
    '<leader>e',
    function()
      Snacks.explorer { cwd = get_root() }
    end,
    desc = 'Explorer',
  },
  {
    '<leader>E',
    function()
      Snacks.explorer()
    end,
    desc = 'Explorer (cwd)',
  },

  -- Git (Lazygit + Snacks Git)
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

  -- Snacks Git native bindings
  {
    '<leader>gs',
    function()
      Snacks.git.status()
    end,
    desc = 'Git Status (Snacks)',
  },
  {
    '<leader>gc',
    function()
      Snacks.git.commits()
    end,
    desc = 'Git Commits',
  },
  {
    '<leader>gC',
    function()
      Snacks.git.bcommits()
    end,
    desc = 'Git Buffer Commits',
  },
  {
    '<leader>gd',
    function()
      Snacks.git.diff()
    end,
    desc = 'Git Diff Current File',
  },
  {
    '<leader>gh',
    function()
      Snacks.git.hunks()
    end,
    desc = 'Git Hunks',
  },
  {
    '<leader>gH',
    function()
      Snacks.git.history()
    end,
    desc = 'Git File History',
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
