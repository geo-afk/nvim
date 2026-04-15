--------------------------------------------------------------------------------
-- terminal_manager/highlights.lua
-- Defines all highlight groups used by the plugin.
-- All groups use `default = true` so a colorscheme or the user's init.lua
-- can override them without requiring any extra setup.
--------------------------------------------------------------------------------

local M = {}

function M.setup()
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", opts, { default = true }))
  end

  -- ── Sidebar chrome ────────────────────────────────────────────────────────
  hl("TermManagerHeader", { link = "Title" }) -- "▌ TERMINALS" line
  hl("TermManagerSep", { link = "FloatBorder" }) -- separator lines
  hl("TermManagerNew", { link = "SpecialKey" }) -- "+" glyph
  hl("TermManagerHelpHint", { link = "Comment" }) -- "?" glyph

  -- ── Terminal entry states (whole-line highlight) ───────────────────────────
  hl("TermManagerActive", { link = "PmenuSel" }) -- active terminal row
  hl("TermManagerAlive", { link = "Normal" }) -- running, not active
  hl("TermManagerDead", { link = "Comment" }) -- shell exited
  hl("TermManagerPlaceholder", { link = "Comment" }) -- "(no terminals)" text

  -- ── Glyph-level highlights (applied over the full-line hl) ────────────────
  hl("TermManagerArrow", { link = "DiagnosticOk" }) -- ▶ on the active row

  -- ── Winbar ────────────────────────────────────────────────────────────────
  hl("TermManagerWinbarDot", { link = "DiagnosticOk" })
  hl("TermManagerWinbar", { link = "WinBar" })
  hl("TermManagerWinbarHint", { link = "Comment" })

  -- ── Profile accent colours for the status dot (● / ○) ────────────────────
  -- Kept separate so the dot stands out even inside a PmenuSel row.
  local accent = {
    Blue = "DiagnosticInfo",
    Green = "DiagnosticOk",
    Red = "DiagnosticError",
    Yellow = "DiagnosticWarn",
    Cyan = "DiagnosticHint",
    Magenta = "Special",
    Orange = "WarningMsg",
    White = "Normal",
  }
  for cap, target in pairs(accent) do
    hl("TermManagerAccent" .. cap, { link = target })
  end
end

--- Map a profile color string → its highlight group name.
---@param color string|nil
---@return string
function M.accent_hl(color)
  local c = tostring(color or "blue")
  return "TermManagerAccent" .. c:sub(1, 1):upper() .. c:sub(2):lower()
end

return M
