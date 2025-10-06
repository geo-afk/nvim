local color_theme = require 'constants.lualine-const'

return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'lewis6991/gitsigns.nvim',
    },
    event = 'VeryLazy',
    config = function()
      -- ================================================================================================
      -- CUSTOM COMPONENTS
      -- ================================================================================================

      -- Scrollbar Component
      local scrollbar_component = require('lualine.component'):extend()

      function scrollbar_component:init(opts)
        opts.reverse = opts.reverse or false
        scrollbar_component.super.init(self, opts)
      end

      function scrollbar_component:update_status()
        local scroll_bar_blocks = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }
        local curr_line = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_line_count(0)

        if lines == 0 or curr_line > lines then
          return ''
        end

        if self.options.reverse then
          return string.rep(scroll_bar_blocks[8 - math.floor(curr_line / lines * 7)], 2)
        else
          return string.rep(scroll_bar_blocks[math.floor(curr_line / lines * 7) + 1], 2)
        end
      end

      -- ================================================================================================
      -- UTILITY FUNCTIONS
      -- ================================================================================================

      local function sanitize(str)
        if not str or str == '' then
          return ''
        end
        return tostring(str):gsub('[<>%%]', ''):gsub('[\r\n]', '')
      end

      -- ================================================================================================
      -- LEFT SIDE COMPONENTS
      -- ================================================================================================

      local function get_filename_with_context()
        local filename = vim.fn.expand '%:t'
        local filepath = vim.fn.expand '%:h'

        if filename == '' then
          return '󰈚 Untitled'
        end

        local modified = vim.bo.modified and ' ●' or ''
        local readonly = vim.bo.readonly and ' 󰌾' or ''
        local context = filepath ~= '.' and filepath ~= '' and '…/' .. vim.fn.fnamemodify(filepath, ':t') .. '/' or ''

        return '  ' .. context .. filename .. modified .. readonly
      end

      local function get_active_lsps()
        local clients = vim.lsp.get_clients { bufnr = 0 }
        if #clients == 0 then
          return ''
        end

        local client_names = {}
        for  _, client in ipairs(clients) do
          if client.name ~= 'null-ls' and client.name ~= 'copilot' then
            local clean_name = client.name:gsub('_', ' '):gsub('^%l', string.upper)
            table.insert(client_names, clean_name)
          end
        end

        if #client_names == 0 then
          return ''
        end

        local lsp_string = table.concat(client_names, ', ')
        if #lsp_string > 25 then
          lsp_string = lsp_string:sub(1, 22) .. '...'
        end

        return '󰿘 ' .. lsp_string
      end

      -- ================================================================================================
      -- GIT COMPONENTS
      -- ================================================================================================

      local function get_git_branch()
        local branch = vim.b.gitsigns_head
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

      -- ================================================================================================
      -- RIGHT SIDE COMPONENTS
      -- ================================================================================================

      local function get_word_count()
        if vim.bo.filetype == 'markdown' or vim.bo.filetype == 'text' or vim.bo.filetype == 'tex' then
          local words = vim.fn.wordcount()
          return '󰈭 ' .. words.words .. 'w'
        end
        return ''
      end

      local function get_location_info()
        local current_line = vim.fn.line '.'
        local total_lines = vim.fn.line '$'
        local column = vim.fn.col '.'
        return string.format('%d:%d/%d', current_line, column, total_lines)
      end

      local function get_lazy_updates()
        return ' ﮮ '
      end

      -- ================================================================================================
      -- LUALINE SETUP
      -- ================================================================================================

      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = color_theme.get_lualine_theme(),
          component_separators = { left = '│', right = '│' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = { 'alpha', 'dashboard', 'snacks_dashboard', 'snacks_notif', 'snacks_terminal', 'snacks_lazygit' },
            winbar = {},
          },
          always_divide_middle = true,
          globalstatus = true,
          refresh = { statusline = 100, tabline = 1000, winbar = 1000 },
        },

        extensions = {
          'mason',
          'lazy',
          -- 'nvim-tree',
          'quickfix',
          'toggleterm',
          'trouble',
        },

        sections = {
          -- ========================================================================================
          -- LEFT SECTION A: MODE & MACRO
          -- ========================================================================================
          lualine_a = {
            {
              'mode',
              fmt = function(str)
                local mode_map = {
                  NORMAL = '󰋙 ',
                  INSERT = '󰏪 I',
                  VISUAL = '󰈈 V',
                  ['V-LINE'] = '󰈈 VL',
                  ['V-BLOCK'] = '󰈈 VB',
                  COMMAND = '󰘳 C',
                  REPLACE = '󰑙 R',
                  ['V-REPLACE'] = '󰑙 VR',
                  SELECT = '󰒉 S',
                  TERMINAL = '󰆍 T',
                }
                return mode_map[str] or str:sub(1, 1)
              end,
              separator = { left = '', right = '' },
              padding = { left = 0, right = 1 },
              color = function()
                return {
                  fg = '#1a1b26', -- Dark foreground for contrast
                  bg = '#7aa2f7', -- Softer blue for mode
                  gui = 'bold',
                }
              end,
            },
          },

          -- ========================================================================================
          -- LEFT SECTION B: GIT INFO
          -- ========================================================================================
          lualine_b = {
            {
              get_git_branch,
              padding = { left = 1, right = 1 },
              separator = { left = '', right = '' },
              color = function()
                local theme = color_theme.get_palette()
                return {
                  fg = theme.bg0 or '#1a1b26',
                  bg = theme.teal or '#4ec9b0', -- Teal for git branch
                  gui = 'bold',
                }
              end,
              cond = function()
                return get_git_branch() ~= ''
              end,
            },
            {
              get_git_added,
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.green, gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
              cond = function()
                return get_git_added() ~= ''
              end,
            },
            {
              get_git_changed,
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.yellow, gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
              cond = function()
                return get_git_changed() ~= ''
              end,
            },
            {
              get_git_removed,
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.red, gui = 'bold' }
              end,
              padding = { left = 1, right = 1 },
              cond = function()
                return get_git_removed() ~= ''
              end,
            },
            {
              get_git_clean,
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.green, gui = 'bold' }
              end,
              padding = { left = 1, right = 1 },
              cond = function()
                return get_git_clean() ~= ''
              end,
            },
          },

          -- ========================================================================================
          -- CENTER SECTION: FILENAME, DIAGNOSTICS & LSP
          -- ========================================================================================
          lualine_c = {
            {
              get_filename_with_context,
              padding = { left = 1, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.fg,
                  gui = vim.bo.modified and 'bold,italic' or 'italic',
                }
              end,
            },
            {
              'diagnostics',
              sources = { 'nvim_diagnostic', 'nvim_lsp' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = '󰌵 ' },
              colored = true,
              update_in_insert = false,
              diagnostics_color = {
                error = function()
                  local colors = color_theme.get_palette()
                  return { fg = colors.red }
                end,
                warn = function()
                  local colors = color_theme.get_palette()
                  return { fg = colors.orange }
                end,
                info = function()
                  local colors = color_theme.get_palette()
                  return { fg = colors.blue }
                end,
                hint = function()
                  local colors = color_theme.get_palette()
                  return { fg = colors.cyan }
                end,
              },
              padding = { left = 1, right = 1 },
            },

            -- Spacer to push LSP to center-right
            {
              function()
                return '%='
              end,
              padding = 0,
            },

            {
              get_active_lsps,
              padding = { left = 1, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.blue,
                  gui = 'bold',
                }
              end,
              separator = { left = '', right = '' },
              cond = function()
                return get_active_lsps() ~= ''
              end,
            },
          },

          -- ========================================================================================
          -- RIGHT SECTION X: NOICE, LAZY, FILE INFO
          -- ========================================================================================
          lualine_x = {
            {
              function()
                return require('noice').api.status.command.get()
              end,
              cond = function()
                return package.loaded['noice'] and require('noice').api.status.command.has()
              end,
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.orange,
                  gui = 'bold',
                }
              end,
              padding = { left = 1, right = 1 },
              separator = { left = '', right = '' },
            },
            {
              get_lazy_updates,
              cond = function()
                return package.loaded['lazy'] and require('lazy.status').has_updates()
              end,
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.yellow,
                  gui = 'bold',
                }
              end,
              separator = { left = '', right = '' },
              padding = { left = 1, right = 1 },
            },
            {
              'fileformat',
              symbols = {
                unix = '󰌽',
                dos = '󰍲',
                mac = '',
              },
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.purple, gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
            },
            {
              'encoding',
              fmt = string.upper,
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.blue, gui = 'bold' }
              end,
              padding = { left = 1, right = 0 },
            },
            {
              get_word_count,
              padding = { left = 1, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.cyan, gui = 'bold' }
              end,
            },
          },

          -- ========================================================================================
          -- RIGHT SECTION Y: FILE TYPE & SIZE
          -- ========================================================================================
          lualine_y = {
            {
              'filetype',
              padding = { left = 2, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.green, gui = 'bold' }
              end,
            },
            {
              'filesize',
              icon = '󰈔',
              cond = function()
                return vim.fn.getfsize(vim.fn.expand '%') > 1024
              end,
              padding = { left = 1, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return { fg = colors.yellow }
              end,
            },
          },

          -- ========================================================================================
          -- RIGHT SECTION Z: LOCATION, SCROLL & TIME
          -- ========================================================================================
          lualine_z = {
            {
              function()
                return '󰕭 ' .. get_location_info()
              end,
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.green,
                  gui = 'bold',
                }
              end,
              separator = { left = ' ', right = '' },
              padding = { left = 1, right = 1 },
            },
            {
              scrollbar_component,
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.yellow,
                  gui = 'bold',
                }
              end,
              separator = { left = '', right = '' },
              padding = { left = 1, right = 1 },
            },
          },
        },

        -- ========================================================================================
        -- INACTIVE SECTIONS
        -- ========================================================================================
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            {
              get_filename_with_context,
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.yellow,
                  gui = 'bold',
                }
              end,
            },
          },
          lualine_x = {
            {
              'location',
              padding = { left = 1, right = 1 },
              color = function()
                local colors = color_theme.get_palette()
                return {
                  fg = colors.bg,
                  bg = colors.yellow,
                  gui = 'bold',
                }
              end,
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
      }

      -- ================================================================================================
      -- AUTOCMDS FOR REFRESH
      -- ================================================================================================

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
          vim.defer_fn(function()
            require('lualine').refresh()
          end, 100)
        end,
      })
    end,
  },
}
