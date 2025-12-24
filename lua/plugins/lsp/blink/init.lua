local constant = require 'plugins.lsp.blink.config'

return {
  'saghen/blink.cmp',
  event = 'VimEnter',
  version = '1.*',

  dependencies = {
    'l3mon4d3/luasnip',
  },

  --- @module 'blink.cmp'
  opts = {
    keymap = {
      preset = 'super-tab',

      ['<tab>'] = {
        function(cmp)
          if cmp.snippet_active() then
            return cmp.accept()
          else
            return cmp.select_and_accept()
          end
        end,
        'snippet_forward',
        'fallback',
      },

      ['<c-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
    },

    appearance = {
      nerd_font_variant = 'mono',
      kind_icons = constant.kind_icons,
    },

    completion = {
      trigger = {
        show_on_backspace_after_accept = true,
        show_on_insert = true,
        show_on_trigger_character = true,
      },

      documentation = {
        auto_show = true,
        auto_show_delay_ms = 400,
        window = {
          border = 'rounded',
        },
        treesitter_highlighting = true,
      },

      menu = {
        auto_show = true,
        auto_show_delay_ms = 0,
        enabled = true,
        min_width = 15,
        max_height = 10,
        border = 'rounded',
        winhighlight = 'Normal:Normal,FloatBorder:None,CursorLine:Visual,Search:None',
        draw = {
          padding = { 0, 0 },
          columns = {
            { 'kind_icon' },
            { 'kind' },
            { 'label' },
          },
          components = constant.components,
        },
      },

      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
    },

    sources = {
      default = function()
        local ok, node = pcall(vim.treesitter.get_node)
        if ok and node and vim.tbl_contains({ 'comment', 'line_comment', 'block_comment' }, node:type()) then
          return { 'buffer' }
        end

        return { 'lazydev', 'lsp', 'path', 'buffer', 'snippets' }
      end,

      per_filetype = {
        lua = { inherit_defaults = true, 'lazydev' },
      },

      providers = {
        buffer = {
          name = 'buffer',
          max_items = 4,
          score_offset = -2,
        },
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          score_offset = 100,
        },
        snippets = {
          name = 'snippets',
          score_offset = -5,
        },
      },
    },

    snippets = {
      preset = 'luasnip',
    },

    fuzzy = {
      implementation = 'lua',
    },

    signature = {
      enabled = true,
      window = {
        min_width = 1,
        max_width = 100,
        max_height = 10,
        border = 'rounded',
        winblend = 0,
        winhighlight = 'Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder',
        scrollbar = false,
        direction_priority = { 'n', 's' },
      },

      trigger = {
        enabled = true,
        show_on_keyword = true,
        show_on_trigger_character = true,
        show_on_insert = true,
        show_on_insert_on_trigger_character = true,
        blocked_trigger_characters = {},
        blocked_retrigger_characters = {},
      },
    },
  },

  opts_extend = {
    'sources.default',
    'sources.providers',
  },
}
