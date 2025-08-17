local snacks_const = require 'constants.snacks_const'

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
    dashboard = { enabled = true },
    indent = {
      enabled = true,
    },
    explorer = {
      enabled = true,
      replace_netrw = true,
      restrict_above_root = true,
      root = function()
        local root_dir = snacks_const.find_git_root()

        if root_dir then
          return root_dir
        end

        local buff_dir = vim.fn.expand '%:p:h'
        return buff_dir
      end,
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
    animate = {
      enabled = true,
      fps = 120, -- high framerate for smoothness
      easing = 'outQuad', -- easing style: linear, inOutQuad, etc.
      duration = 50, -- default animation time (ms)
      scroll = {
        enabled = true,
        duration = 60, -- slightly longer for scrolling
        easing = 'outCubic',
      },
      cursor = {
        enabled = true,
        duration = 40,
        easing = 'inOutSine',
      },
      resize = {
        enabled = false, -- keep window resize instant
      },
      open = {
        enabled = true,
        duration = 70,
      },
      close = {
        enabled = true,
        duration = 70,
      },
    },
    picker = {
      enabled = true,
      win = {
        input = {
          keys = {
            ['<a-c>'] = {
              'toggle_cwd',
              mode = { 'n', 'i' },
            },
          },
        },
      },

      actions = snacks_const.actions,
    },
  },
  keys = snacks_const.keys,
}
