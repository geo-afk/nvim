-- kinds.lua
-- Maps LSP code-action kind strings to display icons (Nerd Font) or
-- two-character ASCII badges when Nerd Fonts are unavailable.
--
-- Longest matching prefix wins (so "refactor.extract" beats "refactor").

local M = {}

-- ── Kind table ───────────────────────────────────────────────────────────────

local KINDS = {
  ["quickfix"] = { icon = "󰁨", badge = "QF" },
  ["refactor"] = { icon = "", badge = "RF" },
  ["refactor.extract"] = { icon = "󰄪", badge = "EX" },
  ["refactor.inline"] = { icon = "󰛦", badge = "IN" },
  ["refactor.move"] = { icon = "󰆼", badge = "MV" },
  ["refactor.rewrite"] = { icon = "󰏫", badge = "RW" },
  ["source"] = { icon = "󱐋", badge = "SR" },
  ["source.organizeImports"] = { icon = "󰋺", badge = "OI" },
  ["source.fixAll"] = { icon = "󰁨", badge = "FA" },
}

local DEFAULT = { icon = "󰌶", badge = "CA" }

-- ── Config ───────────────────────────────────────────────────────────────────

M.use_icons = true

-- ── Setup ─────────────────────────────────────────────────────────────────────

---@param opts table|nil  { use_icons: boolean }
function M.setup(opts)
  if opts and opts.use_icons ~= nil then
    M.use_icons = opts.use_icons
  end
end

-- ── Public API ───────────────────────────────────────────────────────────────

---@param kind string|nil
---@return string
function M.get(kind)
  if not kind or kind == "" then
    return M.use_icons and DEFAULT.icon or DEFAULT.badge
  end

  local best_key = nil
  local best_len = 0
  for key in pairs(KINDS) do
    if (kind == key or vim.startswith(kind, key .. ".")) and #key > best_len then
      best_key = key
      best_len = #key
    end
  end

  if best_key then
    local entry = KINDS[best_key]
    return M.use_icons and entry.icon or entry.badge
  end

  return M.use_icons and DEFAULT.icon or DEFAULT.badge
end

---@return integer
function M.symbol_width()
  return M.use_icons and 1 or 2
end

return M
