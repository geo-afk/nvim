return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    local function is_executable(cmd)
      return vim.fn.executable(cmd) == 1
    end

    local function safe_trash_delete(state)
      local node = state.tree:get_node()
      if not node then
        vim.notify("No node selected for deletion.", vim.log.levels.ERROR)
        return
      end
      local path = node.path
      local is_windows = vim.fn.has("win32") == 1
      local cmd = nil

      if is_windows then
        if is_executable("powershell") then
          cmd = {
            "powershell",
            "-NoProfile",
            "-Command",
            string.format(
              "Add-Type -AssemblyName Microsoft.VisualBasic; "
                .. '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile("%s", "OnlyErrorDialogs", "SendToRecycleBin")',
              path:gsub("\\", "\\\\")
            ),
          }
        else
          vim.notify("PowerShell not found in PATH. Cannot move to Recycle Bin.", vim.log.levels.ERROR)
          return
        end
      else
        if is_executable("trash") then
          cmd = { "trash", path }
        elseif is_executable("trash-put") then -- for trash-cli
          cmd = { "trash-put", path }
        else
          vim.notify(
            "Neither 'trash' nor 'trash-put' found. Install with `brew install trash` or `sudo apt install trash-cli`.",
            vim.log.levels.ERROR
          )
          return
        end
      end

      vim.fn.jobstart(cmd, {
        on_exit = function(_, code)
          if code == 0 then
            require("neo-tree.sources.manager").refresh("filesystem")
          else
            vim.notify("Failed to move file to trash.", vim.log.levels.ERROR)
          end
        end,
      })
    end

    -- Merge with existing opts to avoid overwriting other configurations
    opts.filesystem = vim.tbl_deep_extend("force", opts.filesystem or {}, {
      commands = {
        delete = safe_trash_delete,
      },
      window = {
        mappings = {
          ["d"] = "delete",
        },
      },
    })

    return opts
  end,
}
