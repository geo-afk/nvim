-- =============================================================================
-- lua/custom/autoclose/config.lua
-- Configuration and defaults for smart editing
-- =============================================================================

local M = {}

M.defaults = {
  enabled = true,
  disable_filetypes = {
    "TelescopePrompt",
    "vim",
    "gitcommit",
    "gitrebase",
    "toggleterm",
    "alpha",
    "lazy",
    "mason",
  },
  -- Delimiter pairs to manage
  pairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
  },
  -- Closing delimiters that can be skipped over if typed
  closers = {
    [")"] = true,
    ["]"] = true,
    ["}"] = true,
    ['"'] = true,
    ["'"] = true,
    ["`"] = true,
  },
  -- Syntax nodes where autoclose should be bypassed
  ignored_nodes = {
    "comment",
    "line_comment",
    "block_comment",
    "comment_content",
  },
  -- Nodes where quote pairing is bypassed (to prevent pairing inside strings)
  ignored_quote_nodes = {
    "string",
    "string_content",
    "string_literal",
    "character_literal",
  },
  -- Markdown codeblock syntax
  markdown_fence = "```",
  -- Default keymaps
  keymaps = {
    surround_normal = "<leader>aa", -- normal mode surround (asks for target object, then char)
    surround_visual = "<leader>aa", -- visual mode surround (wraps selection)
    surround_delete = "<leader>ad", -- delete surrounding chars
    surround_replace = "<leader>ar", -- replace surrounding chars
    toggle = "<leader>ua",          -- toggle autoclose globally
  },
}

M.current = vim.tbl_deep_extend("force", {}, M.defaults)

---Get active configuration option
---@param key string
---@return any
function M.get(key)
  return M.current[key]
end

return M
