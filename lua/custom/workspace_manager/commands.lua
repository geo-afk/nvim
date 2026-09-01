--------------------------------------------------------------------------------
-- custom/workspace_manager/commands.lua
-- Global keymaps + :Workspace* user commands.
--------------------------------------------------------------------------------
local M = {}

function M.setup()
  local actions = require("custom.workspace_manager.actions")
  local picker = require("custom.workspace_manager.picker")

  -- ── Keymaps ──────────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<leader>vs", function()
    actions.stash()
  end, { desc = "workspace: stash current window" })

  vim.keymap.set("n", "<leader>vr", function()
    actions.restore()
  end, { desc = "workspace: restore most recent" })

  vim.keymap.set("n", "<leader>vt", function()
    actions.toggle()
  end, { desc = "workspace: toggle stash / restore" })

  vim.keymap.set("n", "<leader>vp", function()
    picker.open()
  end, { desc = "workspace: stashed windows picker" })

  -- ── Commands ─────────────────────────────────────────────────────────────────
  vim.api.nvim_create_user_command("WorkspaceStash", function()
    actions.stash()
  end, { desc = "Stash the current window (hide, don't destroy)" })

  vim.api.nvim_create_user_command("WorkspaceRestore", function()
    actions.restore()
  end, { desc = "Restore the most recently stashed window" })

  vim.api.nvim_create_user_command("WorkspaceToggle", function()
    actions.toggle()
  end, { desc = "Stash the current window, or restore the most recent" })

  vim.api.nvim_create_user_command("WorkspaceList", function()
    picker.open()
  end, { desc = "Open the stashed-windows picker" })

  vim.api.nvim_create_user_command("WorkspaceRename", function(cmd_opts)
    local state = require("custom.workspace_manager.state")
    local item = state.peek()
    if not item then
      vim.notify("Workspace: nothing stashed to rename", vim.log.levels.INFO)
      return
    end
    if cmd_opts.args ~= "" then
      actions.rename(item.id, cmd_opts.args)
      return
    end
    vim.ui.input({ prompt = 'Rename "' .. item.label .. '" to: ', default = item.label }, function(name)
      if name and name ~= "" then
        actions.rename(item.id, name)
      end
    end)
  end, { nargs = "?", desc = "Rename the most recently stashed item" })

  vim.api.nvim_create_user_command("WorkspaceTerminate", function()
    actions.terminate()
  end, { desc = "Terminate the process/session behind the most recently stashed item" })

  vim.api.nvim_create_user_command("WorkspaceRemove", function()
    actions.remove()
  end, { desc = "Drop the most recently stashed item from the registry (leaves it hidden, not restored)" })

  vim.api.nvim_create_user_command("WorkspaceClear", function()
    local n = actions.clear()
    vim.notify(string.format("Workspace: cleared %d stashed item(s) from the registry", n), vim.log.levels.WARN)
  end, { desc = "Drop every stashed item from the registry (does not restore or terminate any of them)" })
end

return M
