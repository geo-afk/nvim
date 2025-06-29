return {
  {
    "nvim-treesitter/nvim-treesitter",
    name = "nvim-treesitter", -- optional, sometimes helps diagnostics
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
      "windwp/nvim-ts-autotag",
    },
    config = function()
      local treesitter = require("nvim-treesitter.configs")
      treesitter.setup({
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
        autotag = {
          enable = true,
        },
        ensure_installed = {
          "json",
          "javascript",
          "typescript",
          "tsx",
          "html",
          "css",
          "markdown",
          "markdown_inline",
          "bash",
          "lua",
          "vim",
          "dockerfile",
          "gitignore",
          "yaml",
          "xml",
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
          },
        },
        -- ✅ Add these to silence diagnostics
        sync_install = false,
        auto_install = true,
        ignore_install = {},
        modules = {}, -- not actually used anymore, but silences LSP warning
      })

      -- Optional but harmless: configure nvim-ts-autotag separately
      local ok, autotag = pcall(require, "nvim-ts-autotag")
      if ok and autotag.setup then
        autotag.setup({
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = false,
          per_filetype = {
            html = {
              enable_close = true,
            },
            xml = {
              enable_close = true,
            },
          },
        })
      end
    end,
  },
}
