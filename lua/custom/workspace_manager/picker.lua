--------------------------------------------------------------------------------
-- custom/workspace_manager/picker.lua
-- Lists everything currently stashed; selecting an entry restores it.
-- Reuses custom.ui's existing picker component (custom/ui/components/picker.lua)
-- rather than pulling in Telescope for a four-line list.
--------------------------------------------------------------------------------
local M = {}

local ICONS = {
  float_term = "󰆍 ",
  managed_terminal = "󰆍 ",
  dap = "󰙨 ",
  overseer_panel = "󰑮 ",
  quickfix = "󰈇 ",
  generic = "󰆧 ",
}

local function format_item(item)
  local icon = ICONS[item.provider] or "󰆧 "
  return string.format("%s %s", icon, item.label)
end

function M.open()
  local state = require("custom.workspace_manager.state")
  local items = state.list()

  if #items == 0 then
    vim.notify("Workspace: nothing stashed", vim.log.levels.INFO)
    return
  end

  require("custom.ui").picker({
    items = items,
    format_item = format_item,
    on_confirm = function(item)
      require("custom.workspace_manager.actions").restore({ id = item.id })
    end,
  })
end

return M
