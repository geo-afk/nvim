local color_theme = require 'constants.lualine-const'

return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'lewis6991/gitsigns.nvim', -- Explicit dependency
    },
    event = 'VeryLazy',
    config = function()
      local function sanitize(str)
        if not str or str == '' then
          return ''
        end
        return tostring(str):gsub('[<>%%]', ''):gsub('[\r\n]', '')
      end

      local function get_line_info()
        local current_line = vim.fn.line '.'
        local total_lines = vim.fn.line '$'
        local column = vim.fn.col '.'
        return string.format(' %d:%d/%d', current_line, column, total_lines)
      end

      local function get_filename()
        local filename = vim.fn.expand '%:t'
        if filename == '' then
          return '[No Name]'
        end
        local modified = vim.bo.modified and ' ' or ''
        local readonly = vim.bo.readonly and ' ' or ''
        return filename .. modified .. readonly
      end

      local function get_active_lsps()
        local clients = vim.lsp.get_clients { bufnr = 0 }
        if #clients == 0 then
          return '' -- Return empty string instead of 'No LSP' for cleaner look
        end

        local client_names = {}
        for _, client in ipairs(clients) do
          if client.name ~= 'null-ls' and client.name ~= 'copilot' then
            local clean_name = client.name:gsub('_', ' '):gsub('^%l', string.upper)
            table.insert(client_names, clean_name)
          end
        end

        if #client_names == 0 then
          return ''
        end

        -- Format with icon and limit display length
        local lsp_string = table.concat(client_names, ', ')
        if #lsp_string > 25 then
          lsp_string = lsp_string:sub(1, 22) .. '...'
        end

        return '󰿘 ' .. lsp_string
      end

      local function get_word_count()
        if vim.bo.filetype == 'markdown' or vim.bo.filetype == 'text' or vim.bo.filetype == 'tex' then
          local words = vim.fn.wordcount()
          return '󰈭 ' .. words.words .. 'w'
        end
        return ''
      end

      local function get_macro_recording()
        local recording_register = vim.fn.reg_recording()
        if recording_register == '' then
          return ''
        end
        return '🎬 @' .. recording_register
      end

      -- Enhanced git branch function with fallback
      local function get_git_branch()
        -- First try gitsigns
        local branch = vim.b.gitsigns_head

        -- Fallback to git command if gitsigns not available
        if not branch or branch == '' then
          local git_dir = vim.fn.finddir('.git', '.;')
          if git_dir ~= '' then
            local handle = io.popen 'git branch --show-current 2>/dev/null'
            if handle then
              branch = handle:read('*a'):gsub('\n', '')
              handle:close()
            end
          end
        end

        if not branch or branch == '' then
          return ''
        end

        branch = sanitize(branch)
        if #branch > 20 then
          branch = branch:sub(1, 17) .. '...'
        end
        return ' ' .. branch
      end

      -- Enhanced git diff functions with better error handling
      local function get_git_added()
        local gitsigns = vim.b.gitsigns_status_dict
        if gitsigns and gitsigns.added and gitsigns.added > 0 then
          return '󰐙 ' .. gitsigns.added
        end
        return ''
      end

      local function get_git_changed()
        local gitsigns = vim.b.gitsigns_status_dict
        if gitsigns and gitsigns.changed and gitsigns.changed > 0 then
          return '󰷈 ' .. gitsigns.changed
        end
        return ''
      end

      local function get_git_removed()
        local gitsigns = vim.b.gitsigns_status_dict
        if gitsigns and gitsigns.removed and gitsigns.removed > 0 then
          return '󰍶 ' .. gitsigns.removed
        end
        return ''
      end

      local function get_git_clean()
        local gitsigns = vim.b.gitsigns_status_dict
        if gitsigns then
          local added = gitsigns.added or 0
          local changed = gitsigns.changed or 0
          local removed = gitsigns.removed or 0

          if added == 0 and changed == 0 and removed == 0 then
            return '󰄬 Clean'
          end
        end
        return ''
      end

      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = color_theme.get_lualine_theme(),
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = { 'alpha', 'dashboard', 'snacks_dashboard', 'snacks_notif', 'snacks_terminal', 'snacks_lazygit' },
            winbar = {},
          },
          always_divide_middle = true,
          globalstatus = true,
          refresh = { statusline = 100, tabline = 1000, winbar = 1000 },
        },
        sections = {
          lualine_a = {
            {
              'mode',
              fmt = function(str)
                local mode_map = {
                  NORMAL = ' 󰋜 N',
                  INSERT = ' 󰏪 I',
                  VISUAL = ' 󰈈 V',
                  ['V-LINE'] = ' 󰈈 VL',
                  ['V-BLOCK'] = ' 󰈈 VB',
                  COMMAND = ' 󰘳 C',
                  REPLACE = ' 󰑙 R',
                  ['V-REPLACE'] = ' 󰑙 VR',
                  SELECT = ' 󰒉 S',
                  TERMINAL = ' T',
                }
                return mode_map[str] or str:sub(1, 1)
              end,
              separator = { left = '', right = '' },
              padding = { left = 0, right = 1 },
              color = function()
                return {
                  fg = '#61afef',
                  bg = '#31353f',
                  gui = 'bold',
                }
              end,
            },
            {
              get_macro_recording,
              cond = function()
                return vim.fn.reg_recording() ~= ''
              end,
              color = { fg = '#ff79c6', gui = 'bold' },
              padding = { left = 0, right = 1 },
            },
          },
          lualine_b = {
            -- Git branch with better visibility
            {
              get_git_branch,
              padding = { left = 1, right = 1 },
              separator = { left = '', right = '' },
              color = function()
                local theme = color_theme.get_palette()
                return {
                  fg = theme.bg0 or '#282c34',
                  bg = theme.blue or '#61afef',
                  gui = 'bold',
                }
              end,
              cond = function()
                return get_git_branch() ~= ''
              end,
            },
            -- Git status indicators with improved conditions
            {
              get_git_added,
              color = function()
                local theme = color_theme.get_palette()
                return { fg = theme.green or '#98c379', gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
              cond = function()
                return get_git_added() ~= ''
              end,
            },
            {
              get_git_changed,
              color = function()
                local theme = color_theme.get_palette()
                return { fg = theme.yellow or '#e5c07b', gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
              cond = function()
                return get_git_changed() ~= ''
              end,
            },
            {
              get_git_removed,
              color = function()
                local theme = color_theme.get_palette()
                return { fg = theme.red or '#e86671', gui = 'bold' }
              end,
              padding = { left = 1, right = 1 },
              cond = function()
                return get_git_removed() ~= ''
              end,
            },
            {
              get_git_clean,
              color = function()
                local theme = color_theme.get_palette()
                return { fg = theme.green or '#98c379', gui = 'bold' }
              end,
              padding = { left = 1, right = 1 },
              cond = function()
                return get_git_clean() ~= ''
              end,
            },
            -- Alternative: Use built-in diff component as fallback
            {
              'diff',
              symbols = { added = '󰐙 ', modified = '󰷈 ', removed = '󰍶 ' },
              diff_color = {
                added = function()
                  local theme = color_theme.get_palette()
                  return { fg = theme.green or '#98c379' }
                end,
                modified = function()
                  local theme = color_theme.get_palette()
                  return { fg = theme.yellow or '#e5c07b' }
                end,
                removed = function()
                  local theme = color_theme.get_palette()
                  return { fg = theme.red or '#e86671' }
                end,
              },
              padding = { left = 1, right = 1 },
              cond = function()
                -- Show built-in diff if custom gitsigns components aren't working
                return vim.b.gitsigns_status_dict == nil and vim.fn.isdirectory '.git' == 1
              end,
            },
          },
          lualine_c = {
            {
              get_filename,
              icon = '󰈙',
              path = 0,
              padding = { left = 1, right = 1 },
            },
            {
              'diagnostics',
              sources = { 'nvim_diagnostic', 'nvim_lsp' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = '󰌵 ' },
              colored = true,
              update_in_insert = false,
              diagnostics_color = {
                error = { fg = color_theme.get_palette().red },
                warn = { fg = color_theme.get_palette().orange },
                info = { fg = color_theme.get_palette().blue },
                hint = { fg = color_theme.get_palette().bg0 },
              },
            },
            {
              function()
                return '%='
              end,
              padding = 10,
            },

            {
              get_active_lsps,
              padding = { left = 1, right = 1 },
              color = function()
                local theme = color_theme.get_palette()
                return {
                  fg = theme.bg0 or '#282c34',
                  bg = theme.purple or '#c678dd',
                  gui = 'bold',
                }
              end,
              separator = { left = '', right = '' },
              cond = function()
                return get_active_lsps() ~= ''
              end,
            },
            {
              function()
                return '%='
              end,
              padding = 0,
            },
          },
          lualine_x = {
            {
              get_word_count,
              padding = { left = 0, right = 1 },
              separator = { left = '', right = '│' },
            },
            {
              'filetype',
              padding = { left = 0, right = 1 },
              separator = { left = '', right = '│' },
            },
          },
          lualine_y = {
            {
              get_line_info,
              icon = '󰉸',
              padding = { left = 0, right = 1 },
              separator = { left = '', right = '│' },
            },
            {
              'filesize',
              icon = '󰈔',
              cond = function()
                return vim.fn.getfsize(vim.fn.expand '%') > 1024
              end,
              padding = { left = 0, right = 1 },
              separator = { left = '', right = '│' },
            },
          },
          lualine_z = {
            {
              function()
                return ' ' .. os.date '%H:%M'
              end,
              padding = { left = 0, right = 1 },
              color = function()
                return {
                  fg = '#61afef',
                  bg = '#31353f',
                  gui = 'bold',
                }
              end,
            },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            {
              get_filename,
              padding = { left = 1, right = 1 },
            },
          },
          lualine_x = {
            {
              'location',
              padding = { left = 1, right = 1 },
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
        extensions = { 'toggleterm', 'quickfix', 'fugitive', 'trouble', 'lazy', 'mason' },
      }

      -- Enhanced autocmds for better git integration
      local group = vim.api.nvim_create_augroup('LualineLSP', { clear = true })
      vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach' }, {
        group = group,
        callback = function()
          require('lualine').refresh()
        end,
      })
      vim.api.nvim_create_autocmd('DiagnosticChanged', {
        group = group,
        callback = function()
          require('lualine').refresh()
        end,
      })

      -- Add git-specific autocmds for better refresh
      vim.api.nvim_create_autocmd({ 'User' }, {
        pattern = 'GitSignsUpdate',
        group = group,
        callback = function()
          require('lualine').refresh()
        end,
      })

      vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
        group = group,
        callback = function()
          -- Refresh when entering buffer or gaining focus (for git changes)
          vim.defer_fn(function()
            require('lualine').refresh()
          end, 100)
        end,
      })

      local palette = color_theme.get_palette()
      vim.api.nvim_set_hl(0, 'LualineLspCenter', {
        fg = palette.fg or '#abb2bf',
        bg = palette.bg2 or '#3e4451',
        italic = true,
      })
    end,
  },
}
