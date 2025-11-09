local CommandHandler = {}

local State = require('custom.commandline.state')
local M = {} -- Config reference

local function setup_command_handler(config)
  M.config = config
end

-- Check if command is a quit command
function CommandHandler:is_quit_command(cmd)
  local quit_patterns = {
    "^q!?$",
    "^quit!?$",
    "^qa!?$",
    "^qall!?$",
    "^wq!?$",
    "^x!?$",
    "^exit!?$",
    "^ZQ$",
    "^ZZ$",
  }
  local trimmed = vim.trim(cmd)
  for _, pattern in ipairs(quit_patterns) do
    if trimmed:match(pattern) then
      return true
    end
  end
  return false
end

-- Get the appropriate window to close
function CommandHandler:get_target_window(cmd)
  if not State.original_win or not vim.api.nvim_win_is_valid(State.original_win) then
    return nil
  end
  -- If it's a quit-all command, return nil to execute normally
  if cmd:match("^qa") or cmd:match("^qall") then
    return nil
  end
  return State.original_win
end

-- Execute command with smart handling
function CommandHandler:execute(cmd)
  local trimmed = vim.trim(cmd)
  if trimmed == "" then
    return true, nil
  end
  -- Handle quit commands specially
  if M.config.features.smart_quit and self:is_quit_command(trimmed) then
    local target_win = self:get_target_window(trimmed)
    if target_win then
      -- Close the original window instead of the cmdline
      local force = trimmed:match("!") ~= nil
      -- For wq/x, save first
      if trimmed:match("^wq") or trimmed:match("^x") or trimmed:match("^ZZ") then
        local buf = vim.api.nvim_win_get_buf(target_win)
        if vim.bo[buf].modified then
          local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
            vim.cmd("write")
          end)
          if not ok then
            return false, "E45: 'readonly' option is set (add ! to override)"
          end
        end
      end
      -- Close the target window
      pcall(vim.api.nvim_win_close, target_win, force)
      return true, nil
    end
  end
  -- Execute command normally
  local ok, err = pcall(vim.cmd, trimmed)
  return ok, err
end

return { CommandHandler = CommandHandler, setup = setup_command_handler }
