return {
  -- Telescope plugin
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8", -- Use the latest stable version or omit for latest commit
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- Add telescope-ui-select as a dependency
      {
        "nvim-telescope/telescope-ui-select.nvim",
      },
    },
    config = function()
      require("telescope").setup({
        extensions = {
          -- Configure telescope-ui-select
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({
              -- Customize dropdown options if needed
              previewer = false,
              layout_config = {
                width = 0.5,
                height = 0.4,
              },
            }),
          },
        },
      })
      -- Load the ui-select extension
      require("telescope").load_extension("ui-select")
    end,
  },
}
