-- highlights.lua
-- Highlight group definitions and per-source colour assignment for code_action_menu.
-- Each unique LSP client is lazily assigned a colour from the SOURCE_PALETTE cycle,
-- so actions from different servers are always visually distinguishable.

local M = {}

-- ── Namespace ────────────────────────────────────────────────────────────────

M.NS = vim.api.nvim_create_namespace("CodeActionMenu")

-- ── Canonical highlight-group names ─────────────────────────────────────────

M.HL = {
  Normal = "CodeActionMenuNormal",
  Border = "CodeActionMenuBorder",
  Title = "CodeActionMenuTitle",
  TitleBg = "CodeActionMenuTitleBg",
  Footer = "CodeActionMenuFooter",
  CursorLine = "CodeActionMenuCursorLine",
  Kind = "CodeActionMenuKind",
  Preferred = "CodeActionMenuPreferred",
  Disabled = "CodeActionMenuDisabled",
  Scrollbar = "CodeActionMenuScrollbar",
  ScrollTrack = "CodeActionMenuScrollTrack",
}

-- ── Per-source colour palette ─────────────────────────────────────────────
-- Six distinct foreground colours that work on both dark and light themes.
-- Extend this table to support more than six unique clients.

local SOURCE_PALETTE = {
  "#7aa2f7", -- blue   (client 1)
  "#9ece6a", -- green  (client 2)
  "#e0af68", -- amber  (client 3)
  "#bb9af7", -- purple (client 4)
  "#2ac3de", -- cyan   (client 5)
  "#f7768e", -- rose   (client 6)
}

-- State: maps client_name → assigned HL group name.
-- Persists across menu invocations so the same client always gets the same colour.
local _source_hl_map = {}
local _source_hl_idx = 0

---Return (and lazily create) the highlight group for a given LSP client name.
---@param client_name string|nil
---@return string  highlight group name
function M.source_hl(client_name)
  if not client_name then
    return M.HL.Disabled
  end

  if _source_hl_map[client_name] then
    return _source_hl_map[client_name]
  end

  _source_hl_idx = (_source_hl_idx % #SOURCE_PALETTE) + 1
  local hl_name = "CodeActionMenuSource" .. _source_hl_idx
  local fg = SOURCE_PALETTE[_source_hl_idx]

  -- Intentionally not `default = true` so user colourscheme changes mid-session
  -- won't silently adopt an old assignment.
  vim.api.nvim_set_hl(0, hl_name, { fg = fg })
  _source_hl_map[client_name] = hl_name
  return hl_name
end

---Return a table of { client_name, hl_group } for all registered sources.
---Used to build the coloured title-bar segments.
---@return { name: string, hl: string }[]
function M.registered_sources()
  local out = {}
  for name, hl in pairs(_source_hl_map) do
    table.insert(out, { name = name, hl = hl })
  end
  return out
end

-- ── Setup ────────────────────────────────────────────────────────────────────

---Register all highlight groups.  Safe to call multiple times.
---`default = true` lets the user's colourscheme win; only our fallback is set here.
function M.setup()
  -- Window body: link to Normal so the float blends with the editor background.
  -- This deliberately avoids NormalFloat, which many themes shade differently.
  vim.api.nvim_set_hl(0, M.HL.Normal, { link = "Normal", default = true })

  -- Inherit FloatBorder's foreground colour but strip any background so the
  -- rounded border lines are transparent, matching the float body.
  local border_base = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  vim.api.nvim_set_hl(0, M.HL.Border, {
    fg = border_base.fg,
    bg = "NONE",
    default = true,
  })

  -- Title bar: use FloatTitle as the base but give it a background tint so it
  -- reads as a distinct bar rather than just text floating in the border line.
  vim.api.nvim_set_hl(0, M.HL.Title, { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, M.HL.TitleBg, { link = "TabLineSel", default = true })

  vim.api.nvim_set_hl(0, M.HL.Footer, { link = "FloatFooter", default = true })
  vim.api.nvim_set_hl(0, M.HL.CursorLine, { link = "PmenuSel", default = true })
  vim.api.nvim_set_hl(0, M.HL.Kind, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, M.HL.Preferred, { link = "DiagnosticHint", default = true })
  vim.api.nvim_set_hl(0, M.HL.Disabled, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, M.HL.Scrollbar, { link = "PmenuThumb", default = true })
  vim.api.nvim_set_hl(0, M.HL.ScrollTrack, { link = "PmenuSbar", default = true })

  -- Pre-register the six palette groups so they exist even before any client
  -- has been seen (prevents "unknown highlight group" warnings from winhighlight).
  for i, fg in ipairs(SOURCE_PALETTE) do
    vim.api.nvim_set_hl(0, "CodeActionMenuSource" .. i, { fg = fg, default = true })
  end
end

return M
