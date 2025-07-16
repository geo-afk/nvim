return {
  {
    "ray-x/go.nvim",
    dependencies = { -- optional but recommended
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
      "maxandron/goplements.nvim",
    },
    config = function()
      require("go").setup({
        goimports = "goimports", -- Use goimports for import organization
        gofmt = "gofumpt", -- Use gofumpt for stricter formatting
        lsp_cfg = true, -- Use go.nvim's non-default gopls setup
        lsp_gofumpt = true, -- Enable gofumpt in gopls
        verbose = false, -- Avoid excessive logging
        icons = { breakpoint = "🛑", currentpos = "▶️" }, -- Nerd font icons for DAP
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()', -- installs binaries
  },
}
