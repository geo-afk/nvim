local Input = {}
local M = {} -- Config reference
local State = require('custom.commandline.state')
local UI = require('custom.commandline.ui').UI
local Completion = require('custom.commandline.completion').Completion
local Animation = require('custom.commandline.animation').Animation
local debounce = require('custom.commandline.animation').debounce

local trigger_fn

local function setup_input(config)
  M.config = config
  trigger_fn = function()
    if not M.config.completion.enabled or not State.active then
      return
    end
    State.grouped_completions = Completion:get_completions(State.text, State.mode)
    State.flat_items = {}
    for _, item in ipairs(State.grouped_completions) do
      if not item.is_header and not item.is_more then
        table.insert(State.flat_items, item)
      end
    end
    State.comp_index = #State.flat_items > 0 and 1 or 0
    UI:update_display()
  end
  Input.trigger_completion = debounce(trigger_fn, M.config.completion.delay)
end

function Input:handle_char(char)
  State:push_undo()
  local before = State.text:sub(1, State.cursor_pos - 1)
  local after = State.text:sub(State.cursor_pos)
  if M.config.features.auto_pairs then
    local pairs = { ["("] = ")", ["["] = "]", ["{"] = "}", ["'"] = "'", ['"'] = '"' }
    if pairs[char] and not after:match("^%w") then
      State.text = before .. char .. pairs[char] .. after
      State.cursor_pos = State.cursor_pos + 1
      UI:update_display()
      self:trigger_completion()
      return
    end
  end
  State.text = before .. char .. after
  State.cursor_pos = State.cursor_pos + 1
  UI:update_display()
  self:trigger_completion()
end

function Input:handle_backspace()
  if State.cursor_pos > 1 then
    State:push_undo()
    State.text = State.text:sub(1, State.cursor_pos - 2) .. State.text:sub(State.cursor_pos)
    State.cursor_pos = State.cursor_pos - 1
    UI:update_display()
    self:trigger_completion()
  end
end

function Input:handle_movement(dir)
  if dir == "left" then
    State.cursor_pos = math.max(1, State.cursor_pos - 1)
  elseif dir == "right" then
    State.cursor_pos = math.min(#State.text + 1, State.cursor_pos + 1)
  elseif dir == "home" then
    State.cursor_pos = 1
  elseif dir == "end" then
    State.cursor_pos = #State.text + 1
  end
  UI:update_display()
end

function Input:handle_history(dir)
  local hist_type = State.mode == ":" and "cmd" or "search"
  if dir == "up" then
    State.history_index = State.history_index + 1
    local item = vim.fn.histget(hist_type, -State.history_index)
    if item and item ~= "" then
      State.text = item
      State.cursor_pos = #State.text + 1
      UI:update_display()
    else
      State.history_index = State.history_index - 1
    end
  else
    State.history_index = math.max(0, State.history_index - 1)
    State.text = State.history_index == 0 and "" or (vim.fn.histget(hist_type, -State.history_index) or "")
    State.cursor_pos = #State.text + 1
    UI:update_display()
  end
end

function Input:select_completion()
  if State.comp_index > 0 and State.comp_index <= #State.flat_items then
    local item = State.flat_items[State.comp_index]
    State:push_undo()
    local word_start = State.text:match("()%S+$") or State.cursor_pos
    local before = State.text:sub(1, word_start - 1)
    State.text = before .. item.text
    State.cursor_pos = #State.text + 1
    State.grouped_completions = {}
    State.flat_items = {}
    State.comp_index = 0
    UI:update_display()
    Animation:pulse(State.win)
  end
end

function Input:navigate_completion(dir)
  if #State.flat_items == 0 then
    return
  end
  if dir == "next" then
    State.comp_index = State.comp_index % #State.flat_items + 1
  else
    State.comp_index = State.comp_index - 1
    if State.comp_index < 1 then
      State.comp_index = #State.flat_items
    end
  end
  UI:update_display()
end

function Input:setup_keymaps()
  local opts = { buffer = State.buf, noremap = true, silent = true }
  -- Printable characters (loop for common ASCII; extend as needed)
  for i = 32, 126 do
    local char = string.char(i)
    vim.keymap.set("i", char, function()
      self:handle_char(char)
    end, opts)
  end
  -- Editing (modern keymaps with buffer scope)
  vim.keymap.set("i", "<BS>", function()
    self:handle_backspace()
  end, opts)
  vim.keymap.set("i", "<C-h>", function()
    self:handle_backspace()
  end, opts)
  vim.keymap.set("i", "<C-w>", function()
    State:push_undo()
    local word_start = State.text:sub(1, State.cursor_pos - 1):match("()%S+%s*$") or 1
    State.text = State.text:sub(1, word_start - 1) .. State.text:sub(State.cursor_pos)
    State.cursor_pos = word_start
    UI:update_display()
  end, opts)
  vim.keymap.set("i", "<C-u>", function()
    State:push_undo()
    State.text = ""
    State.cursor_pos = 1
    UI:update_display()
  end, opts)
  -- Movement
  vim.keymap.set("i", "<Left>", function()
    self:handle_movement("left")
  end, opts)
  vim.keymap.set("i", "<Right>", function()
    self:handle_movement("right")
  end, opts)
  vim.keymap.set("i", "<Home>", function()
    self:handle_movement("home")
  end, opts)
  vim.keymap.set("i", "<End>", function()
    self:handle_movement("end")
  end, opts)
  vim.keymap.set("i", "<C-a>", function()
    self:handle_movement("home")
  end, opts)
  vim.keymap.set("i", "<C-e>", function()
    self:handle_movement("end")
  end, opts)
  vim.keymap.set("i", "<C-b>", function()
    self:handle_movement("left")
  end, opts)
  vim.keymap.set("i", "<C-f>", function()
    self:handle_movement("right")
  end, opts)
  -- History
  vim.keymap.set("i", "<C-p>", function()
    self:handle_history("up")
  end, opts)
  vim.keymap.set("i", "<C-n>", function()
    self:handle_history("down")
  end, opts)
  -- Completion (Tab for select/next, Shift-Tab for prev)
  vim.keymap.set("i", "<Tab>", function()
    if #State.flat_items > 0 then
      self:select_completion()
    else
      self:trigger_completion()
    end
  end, opts)
  vim.keymap.set("i", "<S-Tab>", function()
    self:navigate_completion("prev")
  end, opts)
  vim.keymap.set("i", "<Down>", function()
    if #State.flat_items > 0 then
      self:navigate_completion("next")
    else
      self:handle_history("down")
    end
  end, opts)
  vim.keymap.set("i", "<Up>", function()
    if #State.flat_items > 0 then
      self:navigate_completion("prev")
    else
      self:handle_history("up")
    end
  end, opts)
  -- Undo/Redo
  vim.keymap.set("i", "<C-z>", function()
    if State:undo() then
      UI:update_display()
    end
  end, opts)
  vim.keymap.set("i", "<C-y>", function()
    if State:redo() then
      UI:update_display()
    end
  end, opts)
  -- Execute/Cancel (best practice: use vim.cmd for stopinsert)
  vim.keymap.set("i", "<CR>", function()
    require('custom.commandline.main').execute()
  end, opts)
  vim.keymap.set("i", "<Esc>", function()
    require('custom.commandline.main').close()
  end, opts)
  vim.keymap.set("i", "<C-c>", function()
    require('custom.commandline.main').close()
  end, opts)
end

return { Input = Input, setup = setup_input }
