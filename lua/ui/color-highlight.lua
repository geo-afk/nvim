return {
  {
    "brenoprata10/nvim-highlight-colors",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-highlight-colors").setup({
        render = "virtual", -- other options: "foreground" or "virtual" or "background"
        enable_named_colors = true,
        enable_tailwind = true,
      })
    end,
  },
}
