local openNotif = require 'plugins.snacks.notifier'
local PICKER = require 'plugins.snacks.picker'

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    picker = {
      enabled = true,
      sources = {
        undo = {
          win = {
            input = {
              keys = {
                ['<CR>'] = { 'yank_add', mode = 'i' },
                ['<D-c>'] = { 'yank_del', mode = 'i' },
              },
            },
          },
          layout = 'big_preview',
        },
        marks = {
          transform = function(item)
            return item.label:find '%u' ~= nil
          end, -- only global marks
          win = {
            input = {
              keys = { ['<D-d>'] = { 'delete_mark', mode = 'i' } },
            },
          },
        },
        notifications = {
          formatters = { severity = { level = false } },
          confirm = function(picker)
            local pickerIdx = picker:current().idx
            picker:close()
            openNotif(pickerIdx)
          end,
        },
      },
    },
    undo = {
      enabled = true,
    },
    notifier = {
      enabled = true,
      timeout = 7500,
      sort = { 'added' }, -- sort only by time
      width = { min = 12, max = 0.45 },
      height = { min = 1, max = 0.45 },
      icons = { error = '󰅚', warn = '', info = '󰋽', debug = '󰃤', trace = '󰓗' },
      top_down = false,
    },
    quickfile = { enabled = true },
    scope = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    styles = {
      notification = {
        border = vim.o.winborder,
        focusable = false,
        wo = { winblend = 0, wrap = true },
      },
    },
  },
  keys = require('plugins.snacks.keys').keymappings,
}
