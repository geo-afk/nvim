-- =============================================================================
-- autoclose.lua — Minimal auto-pair implementation
-- =============================================================================

local M = {}

local defaults = {
  pairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
  },
  disable_filetypes = { "TelescopePrompt", "vim" },
}

local config = {}
local _setup_done = false

local function is_disabled()
  return vim.tbl_contains(config.disable_filetypes, vim.bo.filetype)
end

function M.setup(opts)
  if _setup_done then
    return
  end
  _setup_done = true
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("AutoClose", { clear = true })

  for open, close in pairs(config.pairs) do
    vim.keymap.set("i", open, function()
      if is_disabled() then
        return open
      end

      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local next_char = line:sub(col + 1, col + 1)

      -- If the closing pair is right ahead, just move past it (for quotes/braces)
      if open == close and next_char == close then
        return "<Right>"
      end

      -- If next char is alphanumeric, don't auto-close (prevents 'word(' -> 'word()' which is fine,
      -- but also 'word' -> 'w'o'rd' if you type ' in the middle)
      if next_char:match("%w") then
        return open
      end

      return open .. close .. "<Left>"
    end, { expr = true, buffer = false, desc = "Auto-close " .. open })

    -- Handle backspace to delete pair
    vim.keymap.set("i", "<BS>", function()
      if is_disabled() then
        return "<BS>"
      end

      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local char_before = line:sub(col, col)
      local char_after = line:sub(col + 1, col + 1)

      if config.pairs[char_before] == char_after then
        return "<BS><Del>"
      end

      return "<BS>"
    end, { expr = true, buffer = false, desc = "Auto-close: delete pair" })

    -- Handle CR to expand braces
    if open == "{" then
      vim.keymap.set("i", "<CR>", function()
        if is_disabled() then
          return "<CR>"
        end

        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local char_before = line:sub(col, col)
        local char_after = line:sub(col + 1, col + 1)

        if char_before == "{" and char_after == "}" then
          return "<CR><Esc>O"
        end

        return "<CR>"
      end, { expr = true, buffer = false, desc = "Auto-close: expand braces" })
    end
  end
end

return M
