-- LazyVim configuration for friendly-snippets with LuaSnip

return {
  -- Add LuaSnip as the snippet engine
  {
    "L3MON4D3/LuaSnip",
    -- Ensure friendly-snippets is loaded as a dependency
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local luasnip = require("luasnip")

      -- Load friendly-snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Extend filetypes with additional snippets
      luasnip.filetype_extend("typescript", { "tsdoc" })
      luasnip.filetype_extend("javascript", { "jsdoc", "vue" })
      luasnip.filetype_extend("lua", { "luadoc" })
      luasnip.filetype_extend("python", { "pydoc" })
      luasnip.filetype_extend("rust", { "rustdoc" })
      luasnip.filetype_extend("cs", { "csharpdoc" })
      luasnip.filetype_extend("java", { "javadoc" })
      luasnip.filetype_extend("c", { "cdoc" })
      luasnip.filetype_extend("cpp", { "cppdoc" })
      luasnip.filetype_extend("php", { "phpdoc" })
      luasnip.filetype_extend("kotlin", { "kdoc" })
      luasnip.filetype_extend("ruby", { "rdoc" })
      luasnip.filetype_extend("sh", { "shelldoc" })

      -- Optional: Add custom snippet paths if you have your own snippets
      -- require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })

      -- Optional: Exclude specific snippets if needed
      -- require("luasnip.loaders.from_vscode").load { exclude = { "javascript" } }
    end,
  },

  -- Add friendly-snippets explicitly
  {
    "rafamadriz/friendly-snippets",
    -- Lazy load on LuaSnip dependency
    event = "InsertEnter",
  },
}
