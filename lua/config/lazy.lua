local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Correctly prepend lazypath to runtimepath
vim.opt.rtp:prepend(lazypath)

-- Force Angular component templates to use htmlangular
vim.filetype.add {
  pattern = {
    ['.*%.component%.html'] = 'htmlangular', -- classic Angular template files
    ['.*/src/app/.*%.html'] = function(path, bufnr)
      -- Check if angular.json exists in the project root
      local project_root = vim.fs.find('angular.json', {
        path = path,
        upward = true,
      })[1]

      if project_root then
        return 'htmlangular'
      end

      return 'html' -- fallback to regular html
    end,
  },
}

-- Load your custom configuration first
require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
-- You can also load other setup code here if needed

require('lazy').setup({

  -- 'NMAC427/guess-indent.nvim',
  spec = {
    { import = 'lsp' },
    { import = 'plugins' },
    { import = 'ui' },
    { import = 'tools' },
  },
  defaults = {},
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
  performance = {
    rtp = {
      disable_plugins = {
        'editorconfig',
        'shada',
        'gzip',
        'matchit',
        'netrwPlugin',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
        'man',
        'osc52',
        'spellfile',
      },
    },
  },
})
