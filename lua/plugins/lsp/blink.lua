local constant = require 'plugin.config.blink_util'

return { -- autocompletion
  'saghen/blink.cmp',
  event = 'vimenter',
  version = '1.*',
  dependencies = {
    -- snippet engine
    {
      'l3mon4d3/luasnip',
      version = '2.*',

      build = (function()
        -- build step is needed for regex support in snippets.
        if vim.fn.executable 'make' == 0 then
          return
        end
        return 'make install_jsregexp'
      end)(),
      dependencies = {
        -- `friendly-snippets` contains a variety of premade snippets.
        --    see the readme about individual language/framework/plugin snippets:
        --    https://github.com/rafamadriz/friendly-snippets
        {
          'rafamadriz/friendly-snippets',
          config = function()
            -- require('luasnip.loaders.from_vscode').lazy_load()
          end,
        },
      },
      opts = {},
    },
  },
  --- @module 'blink.cmp'
  opts = {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    this will auto-import if your lsp supports it.
      --    this will expand snippets if the lsp sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- for an understanding of why the 'default' preset is recommended,
      -- you will need to read `:help ins-completion`
      --
      -- no, but seriously. please read `:help ins-completion`, it is really good!
      --
      -- all presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: select next/previous item
      -- <c-e>: hide menu
      -- <c-k>: toggle signature help
      --
      -- see :h blink-cmp-config-keymap for defining your own keymap
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
      -- for more advanced luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/l3mon4d3/luasnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- adjusts spacing to ensure icons are aligned
      -- 'mono' (default) for 'nerd font mono' or 'normal' for 'nerd font'
      nerd_font_variant = 'mono',
      kind_icons = constant.kind_icons,
    },

    completion = {
      trigger = {
        show_on_backspace_after_accept = true,
        show_on_insert = true,
        show_on_trigger_character = true,
      },
      -- by default, you may press `<c-space>` to show the documentation.
      -- optionally, set `auto_show = true` to show the documentation after a delay.
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 400,
        window = {
          border = 'rounded', -- options: "single", "double", "rounded", "solid", "shadow", or "none"
        },
        treesitter_highlighting = true,
      },
      -- ghost_text = { enabled = true },
      menu = {
        auto_show = true,
        auto_show_delay_ms = 0,
        enabled = true,
        min_width = 15,
        max_height = 10,
        border = 'rounded', -- options: "single", "double", "rounded", "solid", "shadow", or "none"
        winhighlight = 'normal:normal,floatborder:none,cursorline:visual,search:none',
        draw = {

          -- columns = { { 'kind_icon', gap = 1 }, { 'label', 'label_description', gap = 1 } },
          columns = { { 'kind_icon' }, { 'label', gap = 1 } },
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
        local success, node = pcall(vim.treesitter.get_node)
        if success and node and vim.tbl_contains({ 'comment', 'line_comment', 'block_comment' }, node:type()) then
          return { 'buffer' }
        end
        -- 👇 snippets placed last
        return { 'lazydev', 'lsp', 'path', 'buffer', 'snippets' }
      end,
      providers = {
        buffer = {
          name = 'buffer',
          max_items = 4,
          score_offset = -2,
        },
        lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        snippets = {
          name = 'snippets',
          score_offset = -5, -- 👈 ensures snippets rank below vars/lsp
        },
      },
    },

    snippets = { preset = 'luasnip' },

    -- blink.cmp includes an optional, recommended rust fuzzy matcher,
    -- which automatically downloads a prebuilt binary when enabled.
    --
    -- by default, we use the lua implementation instead, but you may enable
    -- the rust implementation via `'prefer_rust_with_warning'`
    --
    -- see :h blink-cmp-config-fuzzy for more information
    fuzzy = { implementation = 'lua' },

    -- shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  },
  opts_extend = {
    'sources.default',
    'sources.providers',
  },
}
