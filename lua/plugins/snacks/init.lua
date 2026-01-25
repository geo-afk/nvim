local excluded_dirs = {
  'dist/',
  '.next/',
  '.vite/',
  '.git/',
  '.gitlab/',
  'build/',
  'target/',
  -- add more directories you want hidden here
}

local included_files = {
  '.env', -- always show .env
  'package-lock.json',
  'pnpm-lock.yaml',
  'yarn.lock',
  -- add more specific hidden files you want visible later
}

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
      -- hidden = true, -- top-level: enables hidden files globally
      -- ignored = true, -- top-level: enables git-ignored files globally
      sources = {
        explorer = {
          -- hidden = true, -- ensure explorer shows hidden
          -- ignored = true, -- ensure explorer shows ignored (e.g., node_modules if not excluded)
          -- exclude = excluded_dirs, -- hide these big dirs
          -- include = included_files, -- FORCE show these specific files (takes precedence)
        },
        -- files = {
        --   hidden = true,
        --   ignored = true,
        -- },
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
          end,
          win = {
            input = {
              keys = {
                ['<D-d>'] = { 'delete_mark', mode = 'i' },
              },
            },
          },
        },
        notifications = {
          formatters = {
            severity = { level = false },
          },
          confirm = function(picker)
            if not picker then
              return
            end
            picker:close()
          end,
        },
      },
    },
    undo = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 7500,
      sort = { 'added' },
      width = { min = 12, max = 0.45 },
      height = { min = 1, max = 0.45 },
      icons = {
        error = '󰅚',
        warn = '',
        info = '󰋽',
        debug = '󰃤',
        trace = '󰓗',
      },
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
        wo = {
          winblend = 0,
          wrap = true,
        },
      },
    },
  },
  keys = require('plugins.snacks.keys').keymappings,
}
