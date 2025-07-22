return {
  "saghen/blink.cmp",
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
      -- preset = "default",
      ["<Tab>"] = { "accept", "fallback" },
      ["<C-space>"] = { "show", "fallback" },
      ["<S-k>"] = { "scroll_documentation_up", "fallback" },
      ["<S-j>"] = { "scroll_documentation_down", "fallback" },
    },
    snippets = {
      preset = "luasnip",
      expand = function(snippet)
        require("luasnip").lsp_expand(snippet)
      end,
      active = function(filter)
        if filter and filter.direction then
          return require("luasnip").jumpable(filter.direction)
        end
        return require("luasnip").in_snippet()
      end,
      jump = function(direction)
        require("luasnip").jump(direction)
      end,
    },

    signature = {
      enabled = true,
    },
    completion = {

      ghost_text = {
        enabled = false,
        show_with_menu = false,
      },
      documentation = {
        auto_show = true,
        window = {
          border = "rounded", -- Options: "single", "double", "rounded", "solid", "shadow", or "none"
        },
        treesitter_highlighting = true,
      },
      menu = {
        -- ghost_text = { enabled = true },
        --
        border = "rounded", -- Options: "single", "double", "rounded", "solid", "shadow", or "none"
        draw = {

          -- columns = { { "kind_icon" }, { "label", gap = 1 } },
          columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
          components = {
            -- customize the drawing of kind icons
            kind_icon = {
              text = function(ctx)
                -- default kind icon
                local icon = ctx.kind_icon
                -- if LSP source, check for color derived from documentation
                if ctx.item.source_name == "LSP" then
                  local color_item =
                    require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
                  if color_item and color_item.abbr ~= "" then
                    icon = color_item.abbr
                  end
                end
                return icon .. ctx.icon_gap
              end,
              highlight = function(ctx)
                -- default highlight group
                local highlight = "BlinkCmpKind" .. ctx.kind
                -- if LSP source, check for color derived from documentation
                if ctx.item.source_name == "LSP" then
                  local color_item =
                    require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
                  if color_item and color_item.abbr_hl_group then
                    highlight = color_item.abbr_hl_group
                  end
                end
                return highlight
              end,
            },
          },
        },
      },
    },

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "dadbod" },
      per_filetype = {
        sql = { "dadbod" },
        -- optionally inherit from the `default` sources
        lua = { inherit_defaults = true, "lazydev" },
      },
      providers = {
        dadbod = {
          name = "Dadbod",
          module = "vim_dadbod_completion.blink",
        },
      },
    },

    fuzzy = {
      implementation = "prefer_rust_with_warning",
      sorts = {
        "exact", -- Sorts by exact match, case-sensitive
        "score", -- Primary sort: by fuzzy matching score
        "sort_text", -- Secondary sort: by sortText field if scores are equal
        "label", -- Tertiary sort: by label if still tied
      },
    },
  },
  appearance = {
    -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
    -- Adjusts spacing to ensure icons are aligned
    use_nvim_cmp_as_default = true,
    nerd_font_variant = "mono",
    kind_icons = {
      Copilot = "",
      Text = "󰉿",
      Method = "󰊕",
      Function = "󰊕",
      Constructor = "󰒓",

      Field = "󰜢",
      Variable = "󰆦",
      Property = "󰖷",

      Class = "󱡠",
      Interface = "󱡠",
      Struct = "󱡠",
      Module = "󰅩",

      Unit = "󰪚",
      Value = "󰦨",
      Enum = "󰦨",
      EnumMember = "󰦨",

      Keyword = "󰻾",
      Constant = "󰏿",

      Snippet = "󱄽",
      Color = "󰏘",
      File = "󰈔",
      Reference = "󰬲",
      Folder = "󰉋",
      Event = "󱐋",
      Operator = "󰪚",
      TypeParameter = "󰬛",
    },
  },
  opts_extend = { "sources.default" },
}
