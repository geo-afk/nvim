return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
  },
  opts = {
    cmdline = {
      enabled = true,
      view = 'cmdline_popup', -- Bottom-aligned instead of floating popup
      format = {
        cmdline = { pattern = '^:', icon = '', lang = 'vim' }, -- Custom icon for neatness
        search_down = { kind = 'search', pattern = '^/', icon = ' ', lang = 'regex' },
        search_up = { kind = 'search', pattern = '^%?', icon = ' ', lang = 'regex' },
        filter = { pattern = '^:%s*!', icon = '$', lang = 'bash' },
        lua = { pattern = { '^:%s*lua%s+', '^:%s*lua%s*=%s*', '^:%s*=%s*' }, icon = '', lang = 'lua' },
        help = { pattern = '^:%s*he?l?p?%s+', icon = '?' },
        input = {}, -- Use default
      },
    },
    messages = {
      enabled = true,
      view = 'mini', -- Compact bottom-right bar for messages
      view_error = 'notify', -- Floating for errors (or change to 'mini')
      view_warn = 'notify',
      view_history = 'messages',
      view_search = 'virtualtext',
    },
    popupmenu = {
      enabled = true, -- Keep popupmenu enhanced
      backend = 'nui',
    },
    lsp = {
      progress = {
        enabled = true,
        view = 'mini', -- Bottom bar for LSP loading
      },
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
      hover = { enabled = true },
      signature = { enabled = true },
      message = { enabled = true, view = 'mini' },
    },
    presets = {
      bottom_search = true, -- Search cmdline at bottom
      command_palette = false, -- Disable if you prefer bottom over palette
      long_message_to_split = true, -- Auto-split long messages to bottom
      inc_rename = true, -- Better rename UI
      lsp_doc_border = true, -- Borders for LSP docs
    },
    routes = {
      -- Skip noisy search counts
      {
        filter = { event = 'msg_show', kind = 'search_count' },
        opts = { skip = true },
      },
      -- Route "No information" to skip
      {
        filter = { event = 'msg_show', find = 'No information available' },
        opts = { skip = true },
      },
      -- Send written messages to mini (bottom)
      {
        filter = { event = 'msg_show', kind = '', find = 'written' },
        view = 'mini',
      },
      -- Long messages to a bottom split
      {
        view = 'split',
        filter = { event = 'msg_show', min_height = 10 },
      },
    },
    views = {
      mini = {
        position = { row = -1, col = '100%' }, -- Anchor to bottom-right
        win_options = { winblend = 30 }, -- Slight transparency for neatness
      },
      split = {
        enter = true, -- Auto-enter the split
        position = 'bottom', -- Explicit bottom split
      },
    },
  },
}
