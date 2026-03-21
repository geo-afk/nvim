-- nvim-cmdline/modes.lua
-- Detects the cmdline input subtype from what the user has typed and
-- provides the matching icon, window title, and syntax language.
--
-- BUGFIX: the old substitute pattern "^%s*s[ubstitute]*/" used a
-- Lua character-class [ubstitute] which matched any single char from
-- {b,e,i,s,t,u}, not the word "substitute".  Replaced with "^%s*s%a*/".

local M = {}

-- ---------------------------------------------------------------------------
-- Type annotation
-- ---------------------------------------------------------------------------

---@class CmdlineSubtype
---@field pattern string   Lua pattern (matched against the stripped input)
---@field icon    string   glyph shown in the prompt area
---@field title   string   floating window title
---@field lang    string   :syntax language ("vim"|"lua"|"sh"|"")
---@field is_lua  boolean  true when input body is Lua code

-- ---------------------------------------------------------------------------
-- Subtype definitions — first match wins
-- ---------------------------------------------------------------------------

---@type CmdlineSubtype[]
local SUBTYPES = {
  -- := (Lua expression shorthand, Neovim 0.7+)
  {
    pattern = "^%s*=%s*",
    icon = "  ",
    title = "  Expression  ",
    lang = "lua",
    is_lua = true,
  },
  -- :lua= ...  or  :lua ...
  {
    pattern = "^%s*lua%s*=",
    icon = "  ",
    title = "  Lua eval  ",
    lang = "lua",
    is_lua = true,
  },
  {
    pattern = "^%s*lua%s+",
    icon = "  ",
    title = "  Lua  ",
    lang = "lua",
    is_lua = true,
  },
  -- :help / :h
  {
    pattern = "^%s*h%a*%s+",
    icon = "  ",
    title = "  Help  ",
    lang = "vim",
    is_lua = false,
  },
  -- :! shell command
  {
    pattern = "^%s*!",
    icon = "  ",
    title = "  Shell  ",
    lang = "sh",
    is_lua = false,
  },
  -- :set / :setlocal / :setglobal
  {
    pattern = "^%s*setl?%a*%s+",
    icon = "  ",
    title = "  Options  ",
    lang = "vim",
    is_lua = false,
  },
  -- :s/  :substitute/  — FIX: use %a* instead of [ubstitute]*
  {
    pattern = "^%s*s%a*/",
    icon = "  ",
    title = "  Substitute  ",
    lang = "vim",
    is_lua = false,
  },
  -- :g/  :v/  (global / filter)
  {
    pattern = "^%s*[gv]/",
    icon = "  ",
    title = "  Filter  ",
    lang = "vim",
    is_lua = false,
  },
  -- :r  :w  (file read/write)
  {
    pattern = "^%s*[rw]%s+",
    icon = "  ",
    title = "  File  ",
    lang = "vim",
    is_lua = false,
  },
}

---@type CmdlineSubtype
local DEFAULT_SUBTYPE = {
  pattern = "",
  icon = "  ",
  title = "  Command  ",
  lang = "vim",
  is_lua = false,
}

---@type table<string, CmdlineSubtype>
local SEARCH_SUBTYPES = {
  search_fwd = {
    pattern = "",
    icon = "  ",
    title = "  Search ↓  ",
    lang = "",
    is_lua = false,
  },
  search_bwd = {
    pattern = "",
    icon = "  ",
    title = "  Search ↑  ",
    lang = "",
    is_lua = false,
  },
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Detect the subtype for a cmd-mode input string.
---@param input string
---@return CmdlineSubtype
function M.detect_cmd(input)
  if type(input) ~= "string" then
    return DEFAULT_SUBTYPE
  end
  for _, sub in ipairs(SUBTYPES) do
    if input:match(sub.pattern) then
      return sub
    end
  end
  return DEFAULT_SUBTYPE
end

---Return the fixed subtype for search modes.
---@param mode string  "search_fwd" | "search_bwd"
---@return CmdlineSubtype
function M.detect_search(mode)
  return SEARCH_SUBTYPES[mode] or SEARCH_SUBTYPES.search_fwd
end

---Apply vim :syntax highlighting to `buf`.
---Wrapped in pcall so a missing syntax file never crashes the plugin.
---@param buf  integer
---@param lang string
function M.apply_syntax(buf, lang)
  if type(buf) ~= "number" then
    return
  end
  if type(lang) ~= "string" then
    return
  end
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if lang == "" then
    pcall(vim.api.nvim_set_option_value, "syntax", "OFF", { buf = buf })
  else
    pcall(vim.api.nvim_set_option_value, "syntax", lang, { buf = buf })
  end
end

return M
