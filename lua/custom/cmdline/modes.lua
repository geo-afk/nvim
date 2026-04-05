-- nvim-cmdline/modes.lua
-- Detects the cmdline input subtype from what the user has typed and
-- provides the matching icon, window title, and syntax language.

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
-- Subtype definitions — first match wins (ordered by specificity)
-- ---------------------------------------------------------------------------

---@type CmdlineSubtype[]
local SUBTYPES = {
  -- := (Lua expression shorthand, Neovim 0.7+)
  {
    pattern = "^%s*=%s*",
    icon = "󰲋 ",
    title = "  Expression  ",
    lang = "lua",
    is_lua = true,
  },
  -- :lua= ...  or  :lua ...
  {
    pattern = "^%s*lua%s*=",
    icon = "󰢱 ",
    title = "  Lua eval  ",
    lang = "lua",
    is_lua = true,
  },
  {
    pattern = "^%s*lua%s+",
    icon = "󰢱 ",
    title = "  Lua  ",
    lang = "lua",
    is_lua = true,
  },
  -- :terminal command
  {
    pattern = "^%s*term%a*%s+",
    icon = "󰆍 ",
    title = "  Terminal  ",
    lang = "sh",
    is_lua = false,
  },
  -- :help / :h
  {
    pattern = "^%s*h%a*%s+",
    icon = "󰋗 ",
    title = "  Help  ",
    lang = "vim",
    is_lua = false,
  },
  -- :set / :setlocal / :setglobal
  {
    pattern = "^%s*setl?%a*%s+",
    icon = "󰒓 ",
    title = "  Options  ",
    lang = "vim",
    is_lua = false,
  },
  -- :s/  :substitute/
  {
    pattern = "^%s*s%a*/",
    icon = "󰑕 ",
    title = "  Substitute  ",
    lang = "vim",
    is_lua = false,
  },
  -- :g/  :v/  (global / filter)
  {
    pattern = "^%s*[gv]/",
    icon = "󰈿 ",
    title = "  Filter  ",
    lang = "vim",
    is_lua = false,
  },
  -- :r  :w  (file read/write)
  {
    pattern = "^%s*[rw]%s+",
    icon = "󰈙 ",
    title = "  File  ",
    lang = "vim",
    is_lua = false,
  },
  -- :! shell command
  {
    pattern = "^%s*!",
    icon = "󱁯 ",
    title = "  Shell  ",
    lang = "sh",
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
-- ExtUI availability — cached at module load so we never call pcall/require
-- in the hot path (apply_syntax is called on every keypress).
-- ---------------------------------------------------------------------------

local _extui_available = (function()
  local ok, extui = pcall(require, "vim._extui")
  return ok and extui ~= nil
end)()

-- ---------------------------------------------------------------------------
-- Detection cache — simple table bounded by a max size to prevent unbounded
-- growth.  String keys are safe here; LuaJIT interns short strings.
-- ---------------------------------------------------------------------------

local detect_cache = {}
local detect_cache_size = 0
local CACHE_MAX = 256

function M.clear_cache()
  detect_cache = {}
  detect_cache_size = 0
end

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

  local cached = detect_cache[input]
  if cached then
    return cached
  end

  local result = DEFAULT_SUBTYPE
  for _, sub in ipairs(SUBTYPES) do
    if input:match(sub.pattern) then
      result = sub
      break
    end
  end

  -- Evict cache when it grows too large (simple strategy: nuke and start over)
  if detect_cache_size >= CACHE_MAX then
    detect_cache = {}
    detect_cache_size = 0
  end
  detect_cache[input] = result
  detect_cache_size = detect_cache_size + 1

  return result
end

---Return the fixed subtype for search modes.
---@param mode string  "search_fwd" | "search_bwd"
---@return CmdlineSubtype
function M.detect_search(mode)
  return SEARCH_SUBTYPES[mode] or SEARCH_SUBTYPES.search_fwd
end

---Apply vim :syntax highlighting to `buf`.
---@param buf  integer
---@param lang string
function M.apply_syntax(buf, lang)
  if type(buf) ~= "number" or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if type(lang) ~= "string" then
    lang = ""
  end

  -- When ExtUI is active it manages syntax natively; avoid conflicting with it.
  if _extui_available then
    pcall(function()
      if lang == "" then
        vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
      else
        vim.api.nvim_set_option_value("syntax", lang, { buf = buf })
      end
    end)
    return
  end

  pcall(function()
    if lang == "" then
      vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
    else
      vim.api.nvim_set_option_value("syntax", lang, { buf = buf })
    end
  end)
end

---Get statistics about the detection cache (useful for debugging).
---@return table
function M.get_cache_stats()
  return { cache_size = detect_cache_size, cache_max = CACHE_MAX }
end

return M
