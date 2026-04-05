-- kinds.lua
-- Maps LSP code-action kind strings to display icons (Nerd Font) or
-- two-character ASCII badges when Nerd Fonts are unavailable.
--
-- Longest matching prefix wins (so "refactor.extract" beats "refactor").

local M = {}

-- ── Kind table ───────────────────────────────────────────────────────────────
-- Each entry: { icon = <nerd-font glyph>, badge = <2-char ASCII fallback> }

local KINDS = {
  ["quickfix"] = { icon = "󰁨", badge = "QF" }, -- wrench-fix
  ["refactor"] = { icon = "", badge = "RF" }, -- code-braces
  ["refactor.extract"] = { icon = "󰄪", badge = "EX" }, -- scissors
  ["refactor.inline"] = { icon = "󰛦", badge = "IN" }, -- arrow-collapse
  ["refactor.move"] = { icon = "󰆼", badge = "MV" }, -- file-move
  ["refactor.rewrite"] = { icon = "󰏫", badge = "RW" }, -- pencil
  ["source"] = { icon = "󱐋", badge = "SR" }, -- source-branch
  ["source.organizeImports"] = { icon = "󰋺", badge = "OI" }, -- sort
  ["source.fixAll"] = { icon = "󰁨", badge = "FA" }, -- wrench-all
}

local DEFAULT = { icon = "󰌶", badge = "CA" } -- lightbulb

-- ── Config ───────────────────────────────────────────────────────────────────

---Set to `false` if your terminal / font does not support Nerd Font glyphs.
---The menu falls back to two-character ASCII badges in that case.
M.use_icons = true

-- ── Public API ───────────────────────────────────────────────────────────────

---Return the display symbol for a given LSP kind string.
---Longest matching prefix wins.
---@param kind string|nil
---@return string  one glyph (icon mode) or two chars (badge mode)
function M.get(kind)
  if not kind or kind == "" then
    return M.use_icons and DEFAULT.icon or DEFAULT.badge
  end

  local best_key = nil
  local best_len = 0
  for key, _ in pairs(KINDS) do
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

---Return display width consumed by a kind symbol.
---Nerd Font icons are always single-cell wide; ASCII badges are two cells.
---@return integer
function M.symbol_width()
  return M.use_icons and 1 or 2
end

return M
