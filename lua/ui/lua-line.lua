-- Enhanced Development-Focused Lualine Configuration
-- Place this in lua/plugins/lualine.lua
-- Optimized for OneDark Pro theme with transparent background support

return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'arkav/lualine-lsp-progress',
    },
    event = 'VeryLazy',
    config = function()
      -- Helper functions
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
        local modified = vim.bo.modified and '[+]' or ''
        local readonly = vim.bo.readonly and '[RO]' or ''
        return filename .. modified .. readonly
      end

      local function get_active_lsps()
        local clients = vim.lsp.get_clients { bufnr = 0 }
        if #clients == 0 then
          return '[No LSP]'
        end
        local client_names = {}
        for _, client in pairs(clients) do
          -- Removed null-ls and copilot filtering since you're not using them
          table.insert(client_names, client.name)
        end
        if #client_names == 0 then
          return '[No LSP]'
        end
        return '[' .. table.concat(client_names, ' • ') .. ']'
      end

      -- Separate git diff components for individual coloring
      local function get_git_added()
        local gitsigns = vim.b.gitsigns_status_dict
        if not gitsigns or not gitsigns.added or gitsigns.added <= 0 then
          return ''
        end
        return '+' .. gitsigns.added
      end

      local function get_git_modified()
        local gitsigns = vim.b.gitsigns_status_dict
        if not gitsigns or not gitsigns.changed or gitsigns.changed <= 0 then
          return ''
        end
        return '~' .. gitsigns.changed
      end

      local function get_git_removed()
        local gitsigns = vim.b.gitsigns_status_dict
        if not gitsigns or not gitsigns.removed or gitsigns.removed <= 0 then
          return ''
        end
        return '-' .. gitsigns.removed
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
        return ' @' .. recording_register
      end

      local function get_buffer_count()
        local buffers = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
        return '󰓩 ' .. buffers
      end

      local function get_session_info()
        if vim.g.sessionloaded or (vim.v.this_session and vim.v.this_session ~= '') then
          return '󱂬 Session'
        end
        return ''
      end

      local function get_search_count()
        if vim.v.hlsearch == 0 then
          return ''
        end
        local ok, search = pcall(vim.fn.searchcount)
        if ok and search.total then
          return string.format('󰍉 %d/%d', search.current, search.total)
        end
        return ''
      end

      -- Enhanced color extraction with transparent background support
      local function get_onedarkpro_colors()
        -- Helper function to extract color from highlight groups
        local function get_hl_color(group, attr)
          local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
          if hl[attr] then
            return string.format('#%06x', hl[attr])
          end
          return nil
        end

        -- Check if background is transparent
        local normal_bg = get_hl_color('Normal', 'bg')
        local is_transparent = normal_bg == nil

        -- Try different methods to get OneDark Pro colors
        local colors = {}

        -- Method 1: Try onedarkpro.get_colors()
        local ok1, onedark = pcall(require, 'onedarkpro')
        if ok1 and onedark.get_colors then
          local theme_colors = onedark.get_colors()
          if theme_colors then
            colors = theme_colors
          end
        end

        -- Method 2: Try onedarkpro.colors
        if not next(colors) and ok1 and onedark.colors then
          colors = onedark.colors
        end

        -- Method 3: Try accessing the helper module
        if not next(colors) then
          local ok2, helper = pcall(require, 'onedarkpro.helpers')
          if ok2 and helper.get_colors then
            colors = helper.get_colors()
          end
        end

        -- If we got colors from OneDark Pro, use them
        if next(colors) then
          return {
            bg = is_transparent and 'NONE' or (colors.bg or '#282c34'),
            bg1 = is_transparent and 'NONE' or (colors.bg1 or colors.gray or '#31353f'),
            bg2 = is_transparent and 'NONE' or (colors.bg2 or colors.selection or '#3e4452'),
            fg = colors.fg or '#abb2bf',
            gray = colors.gray or colors.comment or '#5c6370',
            red = colors.red or '#e06c75',
            green = colors.green or '#98c379',
            yellow = colors.yellow or '#e5c07b',
            blue = colors.blue or '#61afef',
            purple = colors.purple or '#c678dd',
            cyan = colors.cyan or '#56b6c2',
            orange = colors.orange or '#d19a66',
            git_add = colors.green or '#98c379',
            git_change = colors.yellow or '#e5c07b',
            git_delete = colors.red or '#e06c75',
          }
        end

        -- Fallback: Extract from highlight groups
        return {
          bg = is_transparent and 'NONE' or (normal_bg or '#282c34'),
          bg1 = is_transparent and 'NONE' or (get_hl_color('CursorLine', 'bg') or '#31353f'),
          bg2 = is_transparent and 'NONE' or (get_hl_color('StatusLine', 'bg') or '#3e4452'),
          fg = get_hl_color('Normal', 'fg') or '#abb2bf',
          gray = get_hl_color('Comment', 'fg') or '#5c6370',
          red = get_hl_color('ErrorMsg', 'fg') or get_hl_color('DiagnosticError', 'fg') or '#e06c75',
          green = get_hl_color('String', 'fg') or get_hl_color('DiffAdd', 'fg') or '#98c379',
          yellow = get_hl_color('WarningMsg', 'fg') or get_hl_color('DiagnosticWarn', 'fg') or '#e5c07b',
          blue = get_hl_color('Function', 'fg') or get_hl_color('Identifier', 'fg') or '#61afef',
          purple = get_hl_color('Constant', 'fg') or get_hl_color('Number', 'fg') or '#c678dd',
          cyan = get_hl_color('Special', 'fg') or get_hl_color('Type', 'fg') or '#56b6c2',
          orange = get_hl_color('PreProc', 'fg') or '#d19a66',
          git_add = get_hl_color('GitSignsAdd', 'fg') or get_hl_color('DiffAdd', 'fg') or '#98c379',
          git_change = get_hl_color('GitSignsChange', 'fg') or get_hl_color('DiffChange', 'fg') or '#e5c07b',
          git_delete = get_hl_color('GitSignsDelete', 'fg') or get_hl_color('DiffDelete', 'fg') or '#e06c75',
        }
      end

      local function create_onedarkpro_theme()
        local colors = get_onedarkpro_colors()

        return {
          normal = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.blue, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          insert = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.green, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          visual = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.purple, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          replace = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.red, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          command = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.yellow, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          terminal = {
            a = { fg = colors.bg == 'NONE' and '#282c34' or colors.bg, bg = colors.cyan, gui = 'bold' },
            b = { fg = colors.fg, bg = colors.bg2 == 'NONE' and colors.gray or colors.bg2 },
            c = { fg = colors.fg, bg = colors.bg },
          },
          inactive = {
            a = { fg = colors.gray, bg = colors.bg1 == 'NONE' and colors.gray or colors.bg1 },
            b = { fg = colors.gray, bg = colors.bg1 == 'NONE' and colors.gray or colors.bg1 },
            c = { fg = colors.gray, bg = colors.bg },
          },
        }
      end

      require('lualine').setup {

        options = {
          icons_enabled = true,
          theme = create_onedarkpro_theme(),
          component_separators = { left = '│', right = '│' },
          -- asymmetry: sharp on the left, rounded on the right
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = { 'alpha', 'dashboard', 'snacks_dashboard', 'snacks_notif', 'snacks_terminal', 'snacks_lazygit' },
            winbar = {},
          },
          globalstatus = true,
        },
        sections = {

          lualine_a = {
            {
              'mode',
              fmt = function(str)
                local mode_map = {
                  ['NORMAL'] = 'N',
                  ['INSERT'] = 'I',
                  ['VISUAL'] = 'V',
                  ['V-LINE'] = 'VL',
                  ['V-BLOCK'] = 'VB',
                  ['COMMAND'] = 'C',
                  ['SELECT'] = 'S',
                  ['S-LINE'] = 'SL',
                  ['S-BLOCK'] = 'SB',
                  ['REPLACE'] = 'R',
                  ['V-REPLACE'] = 'VR',
                  ['TERMINAL'] = 'T',
                }
                return mode_map[str] or str:sub(1, 1)
              end,
              separator = { right = '' }, -- rounded into next section
              padding = { left = 1, right = 1 },
            },
          },
          lualine_b = {
            -- Branch
            {
              'branch',
              icon = '',
              fmt = function(str)
                if #str > 20 then
                  return str:sub(1, 17) .. '...'
                end
                return str
              end,
              separator = { left = '', right = '' },
              padding = { left = 1, right = 1 },
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.blue, gui = 'bold' }
              end,
            },
            -- Git Added (Green)
            {
              get_git_added,
              icon = '',
              separator = '',
              padding = { left = 0, right = 1 },
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.git_add, gui = 'bold' }
              end,
              cond = function()
                return get_git_added() ~= ''
              end,
            },
            -- Git Modified (Yellow)
            {
              get_git_modified,
              icon = '',
              separator = '',
              padding = { left = 0, right = 1 },
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.git_change, gui = 'bold' }
              end,
              cond = function()
                return get_git_modified() ~= ''
              end,
            },
            -- Git Removed (Red)
            {
              get_git_removed,
              icon = '',
              separator = { left = '', right = '' },
              padding = { left = 0, right = 1 },
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.git_delete, gui = 'bold' }
              end,
              cond = function()
                return get_git_removed() ~= ''
              end,
            },
          },
          lualine_c = {
            { get_filename, icon = '󰈙', path = 0, padding = { left = 1, right = 1 } },
            { 'spacer' },
            {
              get_active_lsps,
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.blue, gui = 'bold' }
              end,
              padding = { left = 1, right = 1 },
            },
            { 'spacer' },
            {
              'diagnostics',
              sources = { 'nvim_diagnostic', 'nvim_lsp' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = '󰌵 ' },
              colored = true,
              update_in_insert = false,
              always_visible = false,
              padding = { left = 1, right = 1 },
              diagnostics_color = {
                error = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.red }
                end,
                warn = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.yellow }
                end,
                info = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.blue }
                end,
                hint = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.cyan }
                end,
              },
            },
            { get_search_count, padding = { left = 0, right = 1 } },
          },
          lualine_x = {
            {
              'lsp_progress',
              display_components = { 'lsp_client_name', 'spinner', { 'title', 'percentage', 'message' } },
              colors = {
                use = true,
                lsp_client_name = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.fg }
                end,
                spinner = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.blue }
                end,
                message = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.fg }
                end,
                percentage = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.fg }
                end,
                title = function()
                  local colors = get_onedarkpro_colors()
                  return { fg = colors.fg }
                end,
              },
              separators = {
                component = ' ',
                progress = ' | ',
                message = { pre = '(', post = ')' },
                percentage = { pre = '', post = '%% ' },
                title = { pre = '', post = ': ' },
                lsp_client_name = { pre = '[', post = ']' },
                spinner = { pre = '', post = '' },
              },
              timer = { progress_enddelay = 500, spinner = 120, lsp_client_name_enddelay = 1000 },
              spinner_symbols = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
              padding = { left = 1, right = 1 },
            },
            { get_word_count, padding = { left = 0, right = 1 } },
            { get_session_info, padding = { left = 0, right = 1 } },
            { get_buffer_count, padding = { left = 0, right = 1 } },
            {
              'encoding',
              fmt = function(str)
                return str:upper()
              end,
              cond = function()
                return vim.bo.fileencoding ~= 'utf-8'
              end,
              padding = { left = 0, right = 1 },
            },
            {
              'fileformat',
              symbols = { unix = 'LF', dos = 'CRLF', mac = 'CR' },
              cond = function()
                return vim.bo.fileformat ~= 'unix'
              end,
              padding = { left = 0, right = 1 },
            },
            {
              'filetype',
              colored = true,
              icon_only = false,
              icon = { align = 'right' },
              padding = { left = 0, right = 1 },
            },
          },
          lualine_y = {
            { get_line_info, icon = '󰉸', padding = { left = 1, right = 1 } },
            {
              'filesize',
              icon = '󰈔',
              cond = function()
                return vim.fn.getfsize(vim.fn.expand '%') > 1024
              end,
              padding = { left = 0, right = 1 },
            },
          },
          lualine_z = {
            {
              'progress',
              fmt = function()
                return '%P'
              end,
              padding = { left = 1, right = 1 },
            },
            {
              function()
                return os.date '%H:%M'
              end,
              icon = '󰥔',
              padding = { left = 0, right = 1 },
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
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.gray, bg = colors.bg }
              end,
            },
          },
          lualine_x = {
            {
              'location',
              padding = { left = 1, right = 1 },
              color = function()
                local colors = get_onedarkpro_colors()
                return { fg = colors.gray, bg = colors.bg }
              end,
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {
          'toggleterm',
          'quickfix',
          'fugitive',
          'trouble',
          'lazy',
          'mason',
        },
      }
    end,
  },
}
