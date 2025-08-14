return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'arkav/lualine-lsp-progress',
    },
    event = 'VeryLazy',
    config = function()
      -- Define custom colors for better visual hierarchy
      local colors = {
        bg = '#202328',
        fg = '#bbc2cf',
        yellow = '#ECBE7B',
        cyan = '#008080',
        darkblue = '#081633',
        green = '#98be65',
        orange = '#FF8800',
        violet = '#a9a1e1',
        magenta = '#c678dd',
        blue = '#00008B',
        red = '#ec5f67',
        lightgray = '#E6E6E6',
      }

      -- Custom theme with refined colors
      local custom_theme = {
        normal = {
          a = { fg = colors.darkblue, bg = colors.blue, gui = 'bold' },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
        insert = {
          a = { fg = colors.darkblue, bg = colors.green, gui = 'bold' },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
        visual = {
          a = { fg = colors.darkblue, bg = colors.yellow, gui = 'bold' },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
        replace = {
          a = { fg = colors.darkblue, bg = colors.red, gui = 'bold' },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
        command = {
          a = { fg = colors.darkblue, bg = colors.magenta, gui = 'bold' },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
        inactive = {
          a = { fg = colors.fg, bg = colors.bg },
          b = { fg = colors.fg, bg = colors.bg },
          c = { fg = colors.fg, bg = colors.bg },
        },
      }

      require('lualine').setup {
        options = {
          theme = custom_theme,
          globalstatus = true,
          section_separators = { left = '', right = '' },
          component_separators = { left = '│', right = '│' },
          disabled_filetypes = {
            statusline = { 'NvimTree', 'lazy', 'alpha', 'dashboard', 'Outline' },
            winbar = {},
          },
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = {
            {
              'mode',
              fmt = function(str)
                return str:sub(1, 1) -- Show only first character of mode
              end,
            },
          },
          lualine_b = {
            {
              'branch',
              icon = '',
              color = { fg = colors.violet },
              fmt = function(str)
                if #str > 20 then
                  return str:sub(1, 17) .. '...'
                end
                return str
              end,
            },
            {
              'diff',
              symbols = { added = ' ', modified = ' ', removed = ' ' },
              diff_color = {
                added = { fg = colors.green },
                modified = { fg = colors.orange },
                removed = { fg = colors.red },
              },
            },
            {
              'filename',
              path = 1,
              symbols = {
                modified = ' ●',
                readonly = ' ',
                unnamed = '[No Name]',
                newfile = ' ',
              },
              color = { fg = colors.lightgray },
            },
          },
          lualine_c = {
            {
              'lsp_progress',
              display_components = { 'lsp_client_name', 'spinner', { 'title', 'percentage', 'message' } },
              separators = {
                component = ' ',
                progress = ' | ',
                message = { pre = '(', post = ')' },
                percentage = { pre = '', post = '%% ' },
                title = { pre = '', post = ': ' },
                lsp_client_name = { pre = '[', post = ']' },
                spinner = { pre = '', post = '' },
              },

              spinner_symbols = { '🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘' },
              color = { fg = colors.cyan },
            },
          },
          lualine_x = {
            {
              'diagnostics',
              sources = { 'nvim_diagnostic', 'nvim_lsp' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
              diagnostics_color = {
                color_error = { fg = colors.red },
                color_warn = { fg = colors.yellow },
                color_info = { fg = colors.cyan },
                color_hint = { fg = colors.blue },
              },
            },
            {
              'encoding',
              fmt = string.upper,
              color = { fg = colors.green },
            },
            {
              'fileformat',
              symbols = {
                unix = 'LF',
                dos = 'CRLF',
                mac = 'CR',
              },
              color = { fg = colors.green },
            },
            {
              'filetype',
              colored = true,
              icon_only = false,
              icon = { align = 'right' },
            },
          },
          lualine_y = {
            {
              'progress',
              color = { fg = colors.orange },
            },
          },
          lualine_z = {
            {
              'location',
              color = { fg = colors.yellow, gui = 'bold' },
            },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            {
              'filename',
              path = 1,
              color = { fg = colors.fg },
            },
          },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },
        extensions = { 'nvim-tree', 'lazy', 'mason', 'trouble' },
      }
    end,
  },
}
