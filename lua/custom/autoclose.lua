-- borrowed from nvim/.config/nvim/lua/xaaha/core/autoclose.lua
-- modified with fixes and improvements

local autoclose = {}

local config = {
  keys = {
    ['('] = { escape = false, close = true, pair = '()' },
    ['['] = { escape = false, close = true, pair = '[]' },
    ['{'] = { escape = false, close = true, pair = '{}' },

    ['>'] = { escape = true, close = false, pair = '<>' },
    [')'] = { escape = true, close = false, pair = '()' },
    [']'] = { escape = true, close = false, pair = '[]' },
    ['}'] = { escape = true, close = false, pair = '{}' },

    ['"'] = { escape = true, close = true, pair = '""' },
    ["'"] = { escape = true, close = true, pair = "''" },
    ['`'] = { escape = true, close = true, pair = '``' },

    [' '] = { escape = false, close = true, pair = '  ' },

    ['<BS>'] = {},
    ['<C-H>'] = {},
    ['<C-W>'] = {},
    ['<CR>'] = { disable_command_mode = true },
    ['<S-CR>'] = { disable_command_mode = true },
  },

  options = {
    disabled_filetypes = { 'text' },
    disable_when_touch = false,
    touch_regex = '[%w(%[{]',
    pair_spaces = false,
    auto_indent = true,
    disable_command_mode = false,
  },

  disabled = false,
}

local pair_set = {}
local _setup_done = false

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function insert_get_pair()
  local line = '_' .. vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  return line:sub(col, col + 1)
end

local function command_get_pair()
  local line = '_' .. vim.fn.getcmdline()
  local col = vim.fn.getcmdpos()
  return line:sub(col, col + 1)
end

local function is_pair(pair)
  return pair_set[pair] == true
end

--------------------------------------------------
-- Tree-sitter awareness
--------------------------------------------------

local function in_string_or_comment()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok then
    return false
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  local ok_tree, tree = pcall(function()
    return parser:parse()[1]
  end)

  if not ok_tree or not tree then
    return false
  end

  local root = tree:root()
  local node = root:named_descendant_for_range(row - 1, col, row - 1, col)

  if not node then
    return false
  end

  local t = node:type()
  return t:find("string") ~= nil or t:find("comment") ~= nil
end

--------------------------------------------------
-- Filetype checks
--------------------------------------------------

local function is_disabled(info)
  if config.disabled then
    return true
  end

  local current_filetype = vim.bo.filetype

  for _, filetype in pairs(config.options.disabled_filetypes) do
    if filetype == current_filetype then
      return true
    end
  end

  if info.enabled_filetypes ~= nil then
    for _, filetype in pairs(info.enabled_filetypes) do
      if filetype == current_filetype then
        return false
      end
    end
    return true
  end

  if info.disabled_filetypes ~= nil then
    for _, filetype in pairs(info.disabled_filetypes) do
      if filetype == current_filetype then
        return true
      end
    end
  end

  return false
end

--------------------------------------------------
-- Core handler
--------------------------------------------------

local function handler(key, info, mode)
  if is_disabled(info) then
    return key
  end

  local pair = mode == 'insert' and insert_get_pair() or command_get_pair()

  -- Backspace handling
  if (key == '<BS>' or key == '<C-H>') and is_pair(pair) then
    return '<BS><Del>'
  end

  -- Word delete should behave normally
  if key == '<C-W>' then
    return '<C-W>'
  end

  -- Enter between pairs
  if mode == 'insert' and (key == '<CR>' or key == '<S-CR>') and is_pair(pair) then
    return '<CR><ESC>O' .. (config.options.auto_indent and '' or '<C-D>')
  end

  -- Escape through existing closer
  if info.escape and pair:sub(2, 2) == key then
    return mode == 'insert' and '<C-G>U<Right>' or '<Right>'
  end

  -- Pair insertion
  if info.close then

    -- Skip pairing inside strings/comments
    if in_string_or_comment() then
      return key
    end

    -- Improved apostrophe rule
    if key == "'" then
      local left = pair:sub(1, 1)
      local right = pair:sub(2, 2)

      if left:match('[%w_]') or right:match('[%w_]') then
        return key
      end
    end

    if config.options.disable_when_touch
      and (pair .. '_'):sub(2, 2):match(config.options.touch_regex)
    then
      return key
    end

    -- Space pairing control
    if key == ' ' and (
      not config.options.pair_spaces
      or (config.options.pair_spaces and not is_pair(pair))
      or pair:sub(1,1) == pair:sub(2,2)
    ) then
      return key
    end

    return info.pair .. (mode == 'insert' and '<C-G>U<Left>' or '<Left>')
  end

  return key
end

--------------------------------------------------
-- Setup
--------------------------------------------------

function autoclose.setup(user_config)
  if _setup_done then
    return
  end
  _setup_done = true

  user_config = user_config or {}

  if user_config.keys ~= nil then
    for key, info in pairs(user_config.keys) do
      config.keys[key] = info
    end
  end

  if user_config.options ~= nil then
    for key, value in pairs(user_config.options) do
      config.options[key] = value
    end
  end

  -- Build pair lookup table
  for _, info in pairs(config.keys) do
    if info.pair and info.pair ~= '  ' then
      pair_set[info.pair] = true
    end
  end

  for key, info in pairs(config.keys) do
    vim.keymap.set('i', key, function()
      return (key == ' ' and '<C-]>' or '') .. handler(key, info, 'insert')
    end, { noremap = true, expr = true })

    if not config.options.disable_command_mode and not info.disable_command_mode then
      vim.keymap.set('c', key, function()
        return (key == ' ' and '<C-]>' or '') .. handler(key, info, 'command')
      end, { noremap = true, expr = true })
    end
  end
end

--------------------------------------------------
-- Toggle
--------------------------------------------------

function autoclose.toggle()
  config.disabled = not config.disabled
end

--------------------------------------------------
-- Lazy setup
--------------------------------------------------

vim.api.nvim_create_autocmd('InsertEnter', {
  once = true,
  callback = function()
    if not _setup_done then
      autoclose.setup {}
    end
  end,
})

return autoclose
