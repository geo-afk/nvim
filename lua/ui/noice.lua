return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  enabled = true,
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify', -- optional but looks good with Noice
  },
  opts = {
    notify = {
      enabled = true, -- keep notifications modern
    },
    cmdline = {
      enabled = true,
      view = 'cmdline_popup',
      format = {
        cmdline = { pattern = '', icon = '󱐌 ', lang = 'vim' },
        help = { pattern = '^:%s*he?l?p?%s+', icon = '󰮦 ' },
        search_down = { kind = 'search', pattern = '^/', icon = ' ', lang = 'regex' },
        search_up = { kind = 'search', pattern = '^%?', icon = ' ', lang = 'regex' },
        filter = { pattern = '^:%s*!', icon = ' ', lang = 'bash' },
        lua = {
          pattern = { '^:%s*lua%s+', '^:%s*lua%s*=%s*', '^:%s*=%s*' },
          icon = ' ',
          lang = 'lua',
        },
        input = { view = 'cmdline_input', icon = '󰥻 ' }, -- Used by input()
      },
    },
    views = {
      popup = {
        border = {
          style = 'rounded',
          highlight = 'FloatBorder',
          title = ' NOICE ',
          title_pos = 'center',
        },
      },
      cmdline_popup = {
        border = {
          style = 'rounded',
          highlight = 'NoiceCmdlinePopupBorder',
          title = ' CMD ',
          title_pos = 'center',
        },
        position = {
          row = '40%',
          col = '50%',
        },
        size = {
          width = 60,
          height = 'auto',
        },
      },
      popupmenu = {
        relative = 'editor',
        position = {
          row = 8,
          col = '50%',
        },
        border = {
          style = 'rounded',
          highlight = 'FloatBorder',
        },
        win_options = {
          winhighlight = {
            Normal = 'Normal',
            FloatBorder = 'DiagnosticInfo',
            CursorLine = 'Visual',
            Search = 'None',
          },
        },
      },
      mini = {
        size = {
          width = 'auto',
          height = 'auto',
          max_height = 15,
        },
        position = {
          row = -2,
          col = '100%',
        },
      },
      confirm = {
        backend = 'popup',
        relative = 'editor',
        align = 'center',
        border = {
          style = 'rounded',
          highlight = 'FloatBorder',
          title = ' Confirm ',
          title_pos = 'center',
        },
        position = {
          row = '50%',
          col = '50%',
        },
        size = {
          width = 'auto',
          height = 'auto',
        },
      },
    },
    lsp = {
      progress = { enabled = true },
      -- override = {
      --   ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      --   ['vim.lsp.util.stylize_markdown'] = true,
      --   ['cmp.entry.get_documentation'] = true,
      -- },
      signature = {
        auto_open = { enabled = false },
      },
    },
    routes = {
      {
        filter = {
          event = 'msg_show',
          any = {
            { find = '%d+L, %d+B' },
            { find = '; after #%d+' },
            { find = '; before #%d+' },
            { find = '%d fewer lines' },
            { find = '%d more lines' },
          },
        },
        opts = { skip = true },
      },
    },
    messages = {
      enabled = true, -- must be enabled for prompts
      view = 'notify', -- normal messages go to notify
      view_error = 'notify',
      view_warn = 'notify',
      view_history = 'messages',
      view_search = 'virtualtext',
    },
    health = { checker = true },
    popupmenu = { enabled = true },
    signature = { enabled = true },
  },
  config = function(_, opts)
    require('noice').setup(opts)

    -- Custom highlights for a sleek modern look
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#7aa2f7', bold = true })
    vim.api.nvim_set_hl(0, 'NoiceCmdlinePopupBorder', { fg = '#bb9af7', bold = true })
    vim.api.nvim_set_hl(0, 'NoiceCmdlinePopupTitle', { fg = '#bb9af7', bold = true })
    vim.api.nvim_set_hl(0, 'NoiceCmdlineIcon', { fg = '#e0af68', bold = true })
  end,
}
