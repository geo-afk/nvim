return {
  "saghen/blink.cmp",
  dependencies = {
    "bydlw98/blink-cmp-env",
  },
  version = "1.*",

  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    keymap = {
      preset = "default",
      ["<Tab>"] = { "accept", "fallback" },
      ["C-space"] = { "show", "fallback" },
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = "mono",
    },

    -- (Default) Only show the documentation popup when manually triggered
    completion = { documentation = { auto_show = true } },

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        env = {
          name = "Env",
          module = "blink-cmp-env",
          --- @type blink-cmp-env.Options
          opts = {
            item_kind = require("blink.cmp.types").CompletionItemKind.Variable,
            show_braces = false,
            show_documentation_window = true,
          },
        },
      },
    },
  },
  opts_extend = { "sources.default" },
}
