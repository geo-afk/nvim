-- LazyVim configuration for tailwind-tools.nvim
return {
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      server = {
        override = true, -- Automatically configure tailwindcss-language-server
        settings = {
          tailwindCSS = {
            includeLanguages = {
              elixir = "html-eex",
              eelixir = "html-eex",
              heex = "html-eex",
            },
          },
        },
      },
      document_color = {
        enabled = true, -- Enable inline color hints
        kind = "inline", -- Options: "inline", "foreground", "background"
        inline_symbol = "󰝤 ", -- Symbol for inline mode
        debounce = 200, -- Debounce time in milliseconds for insert mode
      },
      conceal = {
        enabled = false, -- Disable conceal by default, toggle with commands
        min_length = nil, -- Only conceal classes exceeding this length
        symbol = "󱏿", -- Conceal symbol
        highlight = {
          fg = "#38BDF8", -- Highlight color for concealed classes
        },
      },
      keymaps = {
        smart_increment = {
          enabled = true, -- Enable incrementing Tailwind units with <C-a>/<C-x>
          units = {
            { prefix = "border", values = { "2", "4", "6", "8" } },
          },
        },
      },
    },
    config = function(_, opts)
      require("tailwind-tools").setup(opts)
      -- Optional: Register Telescope extension
      require("telescope").load_extension("tailwind")
    end,
  },
  -- Ensure tailwindcss-language-server is installed via mason-lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "tailwindcss" },
    },
  },
  -- Optional: Enhance nvim-cmp with Tailwind colorized completions
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = {
      "roobert/tailwindcss-colorizer-cmp.nvim",
      "onsails/lspkind.nvim",
    },
    opts = function(_, opts)
      local format_kinds = opts.formatting.format
      opts.formatting.format = function(entry, item)
        format_kinds(entry, item)
        return require("tailwindcss-colorizer-cmp").formatter(entry, item)
      end
    end,
  },
}
