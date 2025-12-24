-- Bootstrap lazy.nvim
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
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.neovide'
require 'config.angular'

-- Setup lazy.nvim
require('lazy').setup {
  spec = {
    -- import your plugins
    { import = 'plugins' },
    { import = 'plugins.ui' },
    { import = 'plugins.lsp' },
    { import = 'plugins.tools' },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { 'habamax' } },
  -- automatically check for plugin updates
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'matchit',
        'matchparen',
        'netrwPlugin',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
  ui = {
    border = 'rounded',
    backdrop = 25,
  },
}

-- colorflow.nvim
require('custom.color_highlight').setup {

  render = 'foreground', -- 'background' | 'foreground' | 'virtual'
  mode = 'bg_n_virtual', -- 'fg' | 'bg' | 'virtual' | 'bg_n_virtual'
  border_radius = 0.25,
  enabled = true,
  enable_hex = true,
  enable_short_hex = true,
  enable_rgb = true,
  enable_hsl = true,
  enable_hsl_without_function = true,
  enable_named_colors = true,
  enable_tailwind = false,
  enable_ansi = false,
  enable_var_usage = true,
  -- enable_virtual_text = false,
  virt_text = '󱓻 ',
  virtual_symbol = '■',
  virtual_symbol_prefix = '',
  virtual_symbol_suffix = ' ',
  virtual_symbol_position = 'inline',
}

-- local function wrap(fn, name)
--   return function(...)
--     local info = debug.traceback('', 2)
--     vim.notify(name .. ' called from:\n' .. info, vim.log.levels.DEBUG)
--     return fn(...)
--   end
-- end
--
-- vim.system = wrap(vim.system, 'vim.system')
-- vim.fn.jobstart = wrap(vim.fn.jobstart, 'jobstart')
