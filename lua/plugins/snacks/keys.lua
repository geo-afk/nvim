local openNotif = require 'plugins.snacks.notifier'
local PICKER = require 'plugins.snacks.picker'

local M = {}

M.keymappings = {
  -- General File Operations
  {
    '<leader>?',
    function()
      require('which-key').show { global = false }
    end,
    desc = 'Buffer Local Keymaps (which-key)',
  },
  {
    '<leader>e',
    function()
      Snacks.explorer()
    end,
    -- desc = 'Toggle Snacks File Explorer',
  },
  -- Goto mappings
  { 'go', require('plugins.snacks.picker').betterFileOpen, desc = ' Open files' },
  { 'gP', require('plugins.snacks.picker').browseProject, desc = ' Project' },
  {
    'grr',
    function()
      local openBufs = vim
        .iter(vim.fn.getbufinfo { buflisted = 1 })
        :map(function(buf)
          return buf.name
        end)
        :totable()
      vim.list_extend(vim.v.oldfiles, openBufs)
      Snacks.picker.recent()
    end,
    desc = '󰋚 Recent files',
    nowait = true, -- nvim default mappings starting with `gr`
  },
  {
    'gp',
    function()
      Snacks.picker.files {
        title = '󰈮 Local plugins',
        cwd = vim.fn.stdpath 'data' .. '/lazy',
        exclude = { '*/tests/*', '*.toml', '*.tmux', '*.txt' },
        matcher = { filename_bonus = false }, -- folder more important here
        formatters = { file = { filename_first = false } },
      }
    end,
    desc = '󰈮 Local plugins',
  },
  -- LSP
  {
    'gf',
    function()
      Snacks.picker.lsp_references()
    end,
    desc = '󰈿 References',
  },
  -- `lsp_symbols` tends to too much clutter like anonymous function
  {
    'gs',
    function()
      Snacks.picker.treesitter()
    end,
    desc = '󰐅 Treesitter symbols',
  },
  -- treesitter does not work for markdown, so using LSP symbols here
  {
    'gs',
    function()
      Snacks.picker.lsp_symbols()
    end,
    ft = 'markdown',
    desc = '󰽛 Headings',
  },
  {
    'gw',
    function()
      Snacks.picker.lsp_workspace_symbols()
    end,
    desc = '󰒕 Workspace symbols',
  },
  {
    'g!',
    function()
      Snacks.picker.diagnostics()
    end,
    desc = '󰋼 Workspace diagnostics',
  },
  {
    'g.',
    function()
      Snacks.picker.resume()
    end,
    desc = '󰗲 Resume',
  },
  -- GIT
  {
    '<leader>vb',
    function()
      Snacks.picker.git_branches()
    end,
    desc = '󰗲 Branches',
  },
  {
    '<leader>vs',
    function()
      Snacks.picker.git_status()
    end,
    desc = '󰗲 Status',
  },
  {
    '<leader>vl',
    function()
      Snacks.picker.git_log()
    end,
    desc = '󰗲 Log',
  },
  -- TEMP replacement for tinygit's `interactiveStaging`
  {
    '<leader>va',
    function()
      Snacks.picker.git_diff {
        layout = 'big_preview',
        confirm = function(picker, item)
          -- FIX snacks' `confirm` not working when cwd != git root
          picker:close()
          local gitDir = Snacks.git.get_root()
          local path = (gitDir .. '/' .. item.file):gsub('/', '\\/') -- escape slashes for `:edit`
          local lnum = item.pos[1] + 3 -- +3 since pos is start of diff, not hunk
          vim.cmd(('edit +%d %s'):format(lnum, path))
          vim.cmd.normal { 'zv', bang = true } -- open folds
        end,
        win = {
          input = {
            keys = { ['<Space>'] = { 'stage', mode = 'i' } },
          },
        },
        actions = {
          ['stage'] = function(picker, item)
            local args = { -- https://stackoverflow.com/a/66618356/22114136
              'git',
              'apply',
              '--cached', -- affect staging area, not working tree
              '--verbose', -- more helpful error messages
              '-', -- read patch from stdin
            }
            local patch = item.diff .. '\n'
            local out = vim.system(args, { stdin = patch }):wait()
            if out.code == 0 then
              picker:find() -- refresh
            else
              vim.notify(out.stderr, vim.log.levels.ERROR)
            end
          end,
        },
      }
    end,
    desc = '󰐖 View hunks',
  },
  -- Notifications
  {
    '<Esc>',
    function()
      Snacks.notifier.hide()
    end,
    desc = '󰎟 Dismiss notification',
  },
  {
    '<leader>iN',
    function()
      Snacks.picker.notifications()
    end,
    desc = '󰎟 Notification history',
  },
  -- Info
  {
    '<leader>ih',
    function()
      Snacks.picker.highlights()
    end,
    desc = ' Highlights',
  },
  {
    '<leader>iv',
    function()
      Snacks.picker.help()
    end,
    desc = '󰋖 Vim help',
  },
  {
    '<leader>is',
    function()
      Snacks.picker.pickers()
    end,
    desc = '󰗲 Snacks pickers',
  },
  {
    '<leader>ik',
    function()
      Snacks.picker.keymaps()
    end,
    desc = '󰌌 Keymaps (global)',
  },
  {
    '<leader>iK',
    function()
      Snacks.picker.keymaps { global = false, title = '󰌌 Keymaps (buffer)' }
    end,
    desc = '󰌌 Keymaps (buffer)',
  },
  -- Plugins/UI
  {
    '<leader>pc',
    function()
      Snacks.picker.colorschemes()
    end,
    desc = ' Colorschemes',
  },
  -- Marks
  {
    '<leader>ms',
    function()
      Snacks.picker.marks()
    end,
    desc = '󰃁 Select mark',
  },
  -- Undo

  {
    '<leader>ut',
    function()
      local ok, picker = pcall(function()
        return require('snacks').picker
      end)
      if ok and picker and picker.undo then
        picker.undo()
      else
        vim.notify('Snacks undo picker not available yet', vim.log.levels.WARN)
      end
    end,
    desc = '󰋚 Undo tree',
  },
  -- Quickfix
  {
    '<leader>qq',
    function()
      Snacks.picker.qflist()
    end,
    desc = ' Search qf-list',
  },
}

return M
