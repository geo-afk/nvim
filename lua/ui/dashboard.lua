-- Custom Dashboard-nvim Configuration for Development
-- Place this in your init.lua or as a separate config file

return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  priority = 1000, -- Load early
  config = function()
    require('dashboard').setup {
      theme = 'hyper',
      config = {
        -- Custom header with development theme
        header = {
          '',
          '  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗',
          '  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║',
          '  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║',
          '  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║',
          '  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║',
          '  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝',
          '',
          '           🚀 Ready to build something amazing! 🚀',
          '',
        },

        -- Custom shortcut keys for development workflow
        shortcut = {
          {
            icon = ' ',
            icon_hl = '@variable',
            desc = 'Files',
            group = 'Label',
            action = 'Telescope find_files',
            key = 'f',
          },
          {
            icon = ' ',
            icon_hl = '@function',
            desc = 'New File',
            group = 'DiagnosticHint',
            action = 'enew',
            key = 'n',
          },
          {
            icon = ' ',
            icon_hl = '@keyword',
            desc = 'Live Grep',
            group = 'Number',
            action = 'Telescope live_grep',
            key = 'g',
          },
          {
            icon = ' ',
            icon_hl = '@constant',
            desc = 'Recent Files',
            group = 'String',
            action = 'Telescope oldfiles',
            key = 'r',
          },
          {
            icon = ' ',
            icon_hl = '@type',
            desc = 'Git Status',
            group = 'Keyword',
            action = function()
              if vim.fn.isdirectory '.git' == 1 then
                vim.cmd 'Telescope git_status'
              else
                vim.notify('Not in a git repository', vim.log.levels.WARN)
              end
            end,
            key = 's',
          },
          {
            icon = ' ',
            icon_hl = '@property',
            desc = 'Git Branches',
            group = 'Function',
            action = function()
              if vim.fn.isdirectory '.git' == 1 then
                vim.cmd 'Telescope git_branches'
              else
                vim.notify('Not in a git repository', vim.log.levels.WARN)
              end
            end,
            key = 'b',
          },
          {
            icon = ' ',
            icon_hl = '@variable.builtin',
            desc = 'Projects',
            group = 'Constant',
            action = 'Telescope projects',
            key = 'p',
          },
          {
            icon = ' ',
            icon_hl = '@operator',
            desc = 'Terminal',
            group = 'Type',
            action = 'terminal',
            key = 't',
          },
          {
            icon = ' ',
            icon_hl = '@string.special',
            desc = 'Plugin Manager',
            group = 'Special',
            action = function()
              -- Check which plugin manager is available
              if pcall(require, 'lazy') then
                vim.cmd 'Lazy'
              elseif vim.fn.exists ':PackerSync' == 2 then
                vim.cmd 'PackerSync'
              elseif vim.fn.exists ':PlugInstall' == 2 then
                vim.cmd 'PlugInstall'
              else
                vim.notify('No plugin manager found', vim.log.levels.WARN)
              end
            end,
            key = 'l',
          },
          {
            icon = ' ',
            icon_hl = '@comment',
            desc = 'Config',
            group = 'Comment',
            action = function()
              local config_path = vim.fn.stdpath 'config'
              vim.cmd('edit ' .. config_path .. '/init.lua')
            end,
            key = 'c',
          },
          {
            icon = '󰩈 ',
            icon_hl = '@error',
            desc = 'Quit',
            group = 'Error',
            action = 'quit',
            key = 'q',
          },
        },

        -- Project section for quick access to recent projects
        project = {
          enable = true,
          limit = 8,
          icon = '󰏓 ',
          label = ' Recent Projects:',
          action = 'Telescope find_files cwd=',
        },

        -- MRU (Most Recently Used) files
        mru = {
          limit = 10,
          icon = ' ',
          label = ' Recent Files:',
        },

        -- Custom footer with development tips or quotes
        footer = function()
          local datetime = os.date '%Y-%m-%d %H:%M:%S'
          local version = vim.version()

          return {
            '',
            '📊 Neovim v' .. version.major .. '.' .. version.minor .. '.' .. version.patch,
            '⏰ ' .. datetime,
            '',
            '💡 "Code is like humor. When you have to explain it, it\'s bad." - Cory House',
            '🔥 Happy coding! Remember to commit often and test everything.',
          }
        end,
      },
    }

    -- Hide dashboard if session is being restored
    vim.api.nvim_create_autocmd('VimEnter', {
      group = vim.api.nvim_create_augroup('DashboardSession', { clear = true }),
      callback = function()
        -- Delay to let auto-session do its work first
        vim.defer_fn(function()
          -- Check if we have files loaded or if we started with arguments
          local buffers = vim.api.nvim_list_bufs()
          local has_real_files = false

          for _, buf in ipairs(buffers) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
              local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
              local name = vim.api.nvim_buf_get_name(buf)

              -- If we have a file buffer (not dashboard, not empty, not special)
              if buftype == '' and name ~= '' and not name:match 'dashboard' then
                has_real_files = true
                break
              end
            end
          end

          -- If we have real files loaded (likely from session), hide dashboard
          if has_real_files then
            local dashboard_bufnr = nil
            for _, buf in ipairs(buffers) do
              if vim.api.nvim_buf_is_valid(buf) then
                local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
                if ft == 'dashboard' then
                  dashboard_bufnr = buf
                  break
                end
              end
            end

            if dashboard_bufnr then
              vim.api.nvim_buf_delete(dashboard_bufnr, { force = true })
            end
          end
        end, 50) -- 50ms delay to let auto-session finish
      end,
    })

    -- Custom autocommands for dashboard behavior
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'dashboard',
      callback = function()
        -- Hide statusline on dashboard
        vim.opt_local.laststatus = 0

        -- Custom keymaps for dashboard
        local opts = { buffer = true, silent = true }
        vim.keymap.set('n', 'h', '<cmd>Dashboard<cr>', opts)
        vim.keymap.set('n', '<leader>h', '<cmd>Dashboard<cr>', opts)

        -- Quick navigation keymaps
        vim.keymap.set('n', '<C-p>', '<cmd>Telescope find_files<cr>', opts)
        vim.keymap.set('n', '<C-f>', '<cmd>Telescope live_grep<cr>', opts)
        vim.keymap.set('n', '<C-r>', '<cmd>Telescope oldfiles<cr>', opts)
      end,
    })

    -- Custom commands for dashboard
    vim.api.nvim_create_user_command('DashboardNewSession', function()
      vim.cmd 'Dashboard'
      vim.cmd 'cd ~'
    end, {})

    vim.api.nvim_create_user_command('DashboardFindProject', function()
      require('telescope.builtin').find_files {
        prompt_title = 'Find Project',
        cwd = '~/projects', -- Adjust to your projects directory
        find_command = { 'find', '.', '-type', 'd', '-name', '.git', '-exec', 'dirname', '{}', ';' },
      }
    end, {})
  end,
  dependencies = {
    { 'nvim-tree/nvim-web-devicons' },
    { 'nvim-telescope/telescope.nvim' }, -- For file operations
  },
}
