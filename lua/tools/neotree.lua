return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      commands = {
        delete = function(state)
          local path = state.tree:get_node().path
          vim.fn.jobstart({ "trash", path }, {
            on_exit = function()
              require("neo-tree.sources.manager").refresh("filesystem")
            end,
          })
        end,
      },
      window = {
        mappings = {
          ["d"] = "delete", -- this will now use the new command
        },
      },
    },
  },
}
