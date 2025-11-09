local M = {}

local Config = require('custom.commandline.config')
M.config = Config.config

local Utils = require('custom.commandline.utils')
local AnimationModule = require('custom.commandline.animation')
local Animation = AnimationModule.Animation
local debounce = AnimationModule.debounce
AnimationModule.setup(M.config)

local State = require('custom.commandline.state')

local CommandHandlerModule = require('custom.commandline.command_handler')
local CommandHandler = CommandHandlerModule.CommandHandler
CommandHandlerModule.setup(M.config)

local CompletionModule = require('custom.commandline.completion')
local Completion = CompletionModule.Completion
CompletionModule.setup(M.config)

local UIModule = require('custom.commandline.ui')
local UI = UIModule.UI
UIModule.setup(M.config)

local InputModule = require('custom.commandline.input')
local Input = InputModule.Input
InputModule.setup(M.config)

-- ============================================================================
-- MAIN API
-- ============================================================================
function M.open(mode)
  if State.active then
    return false
  end
  State.active = true
  State.mode = mode or ":"
  State:reset()
  -- Store the window we're coming from (best practice for context restore)
  State.original_win = vim.api.nvim_get_current_win()
  -- Check for visual mode and add range (handle '<,'> automatically)
  local current_mode = vim.fn.mode()
  if current_mode == "v" or current_mode == "V" or current_mode == "\22" then -- \22 is <C-v>
    if State.mode == ":" then
      State.text = "'<,'>"
      State.cursor_pos = #State.text + 1
    end
  end
  if not UI:create_window() then
    State.active = false
    vim.o.cmdheight = 1
    return false
  end
  Input:setup_keymaps()
  UI:update_display()
  -- Deferred completion trigger
  vim.defer_fn(function()
    if State.active then
      Input.trigger_completion()
    end
  end, 100)
  vim.cmd("startinsert")
  return true
end

function M.close()
  if not State.active then
    return
  end
  State.active = false
  Animation:cleanup()
  UI:cleanup()
  -- Return to original window if valid (safe pcall)
  if State.original_win and vim.api.nvim_win_is_valid(State.original_win) then
    pcall(vim.api.nvim_set_current_win, State.original_win)
  end
  State.original_win = nil
  vim.o.cmdheight = 0
  vim.cmd("stopinsert")
end

function M.execute()
  local text = vim.trim(State.text)
  if text == "" then
    M.close()
    return
  end
  Animation:pulse(State.win)
  vim.defer_fn(function()
    M.close()
    vim.defer_fn(function()
      -- Mode-aware command prefix
      local cmd = text
      if State.mode ~= ":" then
        cmd = State.mode .. text
      end
      local ok, err = CommandHandler:execute(cmd)
      if not ok and err then
        vim.notify(tostring(err), vim.log.levels.ERROR)
      end
    end, 50)
  end, 200)
end

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  -- User command (with complete for modes)
  vim.api.nvim_create_user_command("Cmdline", function(args)
    M.open(args.args ~= "" and args.args or ":")
  end, {
    nargs = "?",
    complete = function()
      return { ":", "/", "?", "=" }
    end,
    desc = "Open modern command line",
  })
  -- Default keymaps (use vim.keymap.set for modern Lua)
  vim.keymap.set("n", ":", function()
    M.open(":")
  end, { desc = "Command line" })
  vim.keymap.set("n", "/", function()
    M.open("/")
  end, { desc = "Search" })
  vim.keymap.set("n", "?", function()
    M.open("?")
  end, { desc = "Reverse search" })
  vim.keymap.set("v", ":", function()
    M.open(":")
  end, { desc = "Command with range" })
  -- Cleanup autocommands (group for organization)
  local augroup = vim.api.nvim_create_augroup("ModernCmdline", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      if State.active then
        M.close()
      end
      Animation:cleanup()
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(args)
      if State.win == tonumber(args.match) then
        M.close()
      end
    end,
  })
end

return M
