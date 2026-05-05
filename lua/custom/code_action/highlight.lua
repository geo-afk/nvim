-- highlight.lua
-- Highlight group definitions and per-source colour assignment for code_action_menu.
-- Each unique LSP client is lazily assigned a colour from the SOURCE_PALETTE
-- cycle, so actions from different servers are always visually distinguishable.
--
-- Requires Neovim 0.10+

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
  Header = "CodeActionMenuHeader",
  HeaderCount = "CodeActionMenuHeaderCount",
  Kind = "CodeActionMenuKind",
  Preferred = "CodeActionMenuPreferred",
  Disabled = "CodeActionMenuDisabled",
  PreviewLabel = "CodeActionMenuPreviewLabel",
  PreviewValue = "CodeActionMenuPreviewValue",
  PreviewMeta = "CodeActionMenuPreviewMeta",
  PreviewSign = "CodeActionMenuPreviewSign",
  Scrollbar = "CodeActionMenuScrollbar",
  ScrollTrack = "CodeActionMenuScrollTrack",
  FilterMatch = "CodeActionMenuFilterMatch",
  DiffAdd = "CodeActionMenuDiffAdd",
  DiffDelete = "CodeActionMenuDiffDelete",
  DiffChange = "CodeActionMenuDiffChange",
  DiffHunk = "CodeActionMenuDiffHunk",
}

-- ── Per-source colour palette ─────────────────────────────────────────────

local SOURCE_PALETTE = {
  "#7aa2f7", -- blue
  "#9ece6a", -- green
  "#e0af68", -- amber
  "#bb9af7", -- purple
  "#2ac3de", -- cyan
  "#f7768e", -- rose
}

local _source_hl_map = {}
local _source_hl_idx = 0

---Return (and lazily create) the highlight group for a given LSP client name.
---@param client_name string|nil
---@return string
function M.source_hl(client_name)
  if not client_name then
    return M.HL.Disabled
  end
  if _source_hl_map[client_name] then
    return _source_hl_map[client_name]
  end
  _source_hl_idx = (_source_hl_idx % #SOURCE_PALETTE) + 1
  local hl_name = "CodeActionMenuSource" .. client_name:gsub("[^%w]", "_")
  vim.api.nvim_set_hl(0, hl_name, { fg = SOURCE_PALETTE[_source_hl_idx] })
  _source_hl_map[client_name] = hl_name
  return hl_name
end

---Return all registered sources.
---@return { name: string, hl: string }[]
function M.registered_sources()
  local out = {}
  for name, hl in pairs(_source_hl_map) do
    out[#out + 1] = { name = name, hl = hl }
  end
  return out
end

-- ── Setup ────────────────────────────────────────────────────────────────────

function M.setup()
  vim.api.nvim_set_hl(0, M.HL.Normal, { link = "Normal", default = true })

  local border_base = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  vim.api.nvim_set_hl(0, M.HL.Border, { fg = border_base.fg, bg = "NONE", default = true })

  vim.api.nvim_set_hl(0, M.HL.Title, { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, M.HL.TitleBg, { link = "TabLineSel", default = true })
  vim.api.nvim_set_hl(0, M.HL.Footer, { link = "FloatFooter", default = true })
  vim.api.nvim_set_hl(0, M.HL.CursorLine, { link = "PmenuSel", default = true })
  vim.api.nvim_set_hl(0, M.HL.Header, { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, M.HL.HeaderCount, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, M.HL.Kind, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, M.HL.Preferred, { link = "DiagnosticHint", default = true })
  vim.api.nvim_set_hl(0, M.HL.Disabled, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, M.HL.PreviewLabel, { link = "Identifier", default = true })
  vim.api.nvim_set_hl(0, M.HL.PreviewValue, { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, M.HL.PreviewMeta, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, M.HL.PreviewSign, { link = "LineNr", default = true })
  vim.api.nvim_set_hl(0, M.HL.Scrollbar, { link = "PmenuThumb", default = true })
  vim.api.nvim_set_hl(0, M.HL.ScrollTrack, { link = "PmenuSbar", default = true })
  vim.api.nvim_set_hl(0, M.HL.FilterMatch, { link = "Search", default = true })
  vim.api.nvim_set_hl(0, M.HL.DiffAdd, { link = "DiffAdd", default = true })
  vim.api.nvim_set_hl(0, M.HL.DiffDelete, { link = "DiffDelete", default = true })
  vim.api.nvim_set_hl(0, M.HL.DiffChange, { link = "DiffChange", default = true })
  vim.api.nvim_set_hl(0, M.HL.DiffHunk, { link = "DiffText", default = true })

  for i, fg in ipairs(SOURCE_PALETTE) do
    vim.api.nvim_set_hl(0, "CodeActionMenuSource" .. i, { fg = fg, default = true })
  end

  -- Re-apply per-source groups after colorscheme swap.
  for _, hl_name in pairs(_source_hl_map) do
    local existing = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
    if existing and existing.fg then
      vim.api.nvim_set_hl(0, hl_name, { fg = existing.fg })
    end
  end
end

-- ── ColorScheme refresh ───────────────────────────────────────────────────────

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("CodeActionMenuHighlights", { clear = true }),
  callback = M.setup,
})

return M
