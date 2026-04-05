-- nvim-cmdline/colors.lua
-- "Nightfall+" palette — per-mode accent colours without bleeding into input.
-- Badge:  fg-only accent (no bg)  →  no colour block in the input area.
-- Title:  bg accent segments in the border only  →  correct containment.
-- Hints:  no explicit bg  →  inherits window bg, fg accents pop cleanly.

local M = {}

-- ---------------------------------------------------------------------------
-- Raw palette
-- ---------------------------------------------------------------------------

local P = {
  -- ── Backgrounds ───────────────────────────────────────────────────────────
  -- bg = "#0f1520",
  bg = "NONE",
  popup_bg = "#141b28",
  sel_bg = "#213a58",
  muted_bg = "#131a26",
  border_dim = "#46506b",
  border_glow = "#84bdf7",
  chip_bg = "#1a2333",
  chip_bg_soft = "#172131",

  -- ── Foregrounds ───────────────────────────────────────────────────────────
  fg = "#e6edf3",
  fg2 = "#d0d7de",
  dim = "#677189",
  sub = "#99a2b3",

  -- ── Accent hues ───────────────────────────────────────────────────────────
  cyan = "#79c0ff",
  cyan2 = "#58a6ff",
  amber = "#e3b341",
  amber2 = "#d4a017",
  green = "#56d364",
  green2 = "#3fb950",
  red = "#f85149",
  rose = "#ff7b72",
  lavender = "#a5b4fc",
  orange = "#f0883e",
  lime = "#7ee787",
  teal = "#39d5d3",
  blue = "#58a6ff",
  pink = "#f778ba",

  -- ── Title accent backgrounds (border title only — NOT used anywhere else) ─
  -- These are intentionally ONLY referenced by NvimCmdlineTitle* groups, which
  -- are set exclusively via the floating-window title segment API.  They never
  -- appear in buffer highlights so there is no risk of bleed into the input.
  tbg_cmd = "#12243d",
  tbg_search = "#251a00",
  tbg_lua = "#1b1240",
  tbg_shell = "#0c2218",
  tbg_help = "#0c1e38",
  tbg_opts = "#0a2428",
  tbg_subst = "#2a1400",
  tbg_filter = "#2a0810",
  tbg_file = "#0e2218",

  -- ── Completion kind backgrounds ───────────────────────────────────────────
  kind_bg = "#1f2b3e",
  kind_sel_bg = "#163356",

  -- ── Scrollbar ─────────────────────────────────────────────────────────────
  scroll_thumb = "#4d6fa3",
  scroll_track = "#232b3e",

  -- ── Live preview ──────────────────────────────────────────────────────────
  preview_del_bg = "#2c1a1a",
  preview_add_bg = "#122f1a",
}

-- ---------------------------------------------------------------------------
-- Public: raw palette access
-- ---------------------------------------------------------------------------

function M.get_palette()
  return P
end

-- ---------------------------------------------------------------------------
-- Highlight helper
-- ---------------------------------------------------------------------------

local function hl(name, opts)
  vim.api.nvim_set_hl(0, name, opts)
end

-- ---------------------------------------------------------------------------
-- Highlight definitions
-- ---------------------------------------------------------------------------

function M.setup_highlights()
  local c = P

  -- ── Main cmdline float ────────────────────────────────────────────────────
  hl("NvimCmdlineNormal", { fg = c.fg, bg = c.bg })
  hl("NvimCmdlineBorder", { fg = c.border_glow, bg = c.bg })
  hl("NvimCmdlineFloatTitle", { fg = c.cyan, bg = c.bg, bold = true })
  hl("NvimCmdlineSearchBorder", { fg = c.amber, bg = c.bg })
  hl("NvimCmdlineSearchTitle", { fg = c.amber, bg = c.bg, bold = true })

  -- ── Mode badge icon (fg only — bg comes from the column strip below) ─────────
  hl("NvimCmdlineBadge", { fg = c.cyan, bold = true })
  hl("NvimCmdlineBadgeSearch", { fg = c.amber, bold = true })

  -- Vertical separator between badge column and typed text.
  hl("NvimCmdlineSep", { fg = c.border_dim })
  hl("NvimCmdlineSepSearch", { fg = c.amber2 })

  -- ── Commander layout — solid left column (6 display cells = PROMPT_LEN) ──────
  -- Column background: accent-tinted dark bg for the space cells flanking the icon.
  -- These are ONLY used inside virt_text overlay segments and therefore cannot
  -- bleed past the badge column boundary into the input area.
  hl("NvimCmdlineBadgeCol", { bg = c.tbg_cmd })
  hl("NvimCmdlineBadgeColCmd", { bg = c.tbg_cmd }) -- explicit Cmd variant used by get_badge_hls()
  hl("NvimCmdlineBadgeColSearch", { bg = c.tbg_search })
  hl("NvimCmdlineBadgeColLua", { bg = c.tbg_lua })
  hl("NvimCmdlineBadgeColHelp", { bg = c.tbg_help })
  hl("NvimCmdlineBadgeColShell", { bg = c.tbg_shell })
  hl("NvimCmdlineBadgeColOpts", { bg = c.tbg_opts })
  hl("NvimCmdlineBadgeColSubst", { bg = c.tbg_subst })
  hl("NvimCmdlineBadgeColFilter", { bg = c.tbg_filter })
  hl("NvimCmdlineBadgeColFile", { bg = c.tbg_file })

  -- Label row (second row of badge column) — 3-char mode abbreviation.
  -- bg matches the column strip; fg is the mode accent colour.
  hl("NvimCmdlineBadgeLabel", { fg = c.cyan2, bg = c.tbg_cmd, bold = true })
  hl("NvimCmdlineBadgeLabelCmd", { fg = c.cyan2, bg = c.tbg_cmd, bold = true }) -- explicit Cmd variant
  hl("NvimCmdlineBadgeLabelSearch", { fg = c.amber, bg = c.tbg_search, bold = true })
  hl("NvimCmdlineBadgeLabelLua", { fg = c.lavender, bg = c.tbg_lua, bold = true })
  hl("NvimCmdlineBadgeLabelHelp", { fg = c.blue, bg = c.tbg_help, bold = true })
  hl("NvimCmdlineBadgeLabelShell", { fg = c.green, bg = c.tbg_shell, bold = true })
  hl("NvimCmdlineBadgeLabelOpts", { fg = c.teal, bg = c.tbg_opts, bold = true })
  hl("NvimCmdlineBadgeLabelSubst", { fg = c.orange, bg = c.tbg_subst, bold = true })
  hl("NvimCmdlineBadgeLabelFilter", { fg = c.rose, bg = c.tbg_filter, bold = true })
  hl("NvimCmdlineBadgeLabelFile", { fg = c.lime, bg = c.tbg_file, bold = true })

  -- Completion popup gutter strip — continues the badge column's visual lane
  -- upward into the completion popup so the columns feel structurally connected.
  hl("NvimCmdlineCompGutter", { bg = c.tbg_cmd })
  hl("NvimCmdlineCompGutterSearch", { bg = c.tbg_search })

  -- Prompt spacer (cells between badge and typed text)
  hl("NvimCmdlinePrompt", { fg = c.dim })
  hl("NvimCmdlinePromptSearch", { fg = c.dim })
  hl("NvimCmdlinePromptPad", { bg = c.bg })

  -- ── Hint-line segments ────────────────────────────────────────────────────
  -- No explicit bg — inherits window bg.  fg must be set so segments contrast
  -- properly: keys are bold+bright, descriptions are subdued, separators dim.
  hl("NvimCmdlineHintKey", { fg = c.cyan2, bold = true })
  hl("NvimCmdlineHintKeyCmd", { fg = c.cyan2, bold = true }) -- explicit Cmd variant used by get_hint_key_hl()
  hl("NvimCmdlineHintKeySearch", { fg = c.amber, bold = true })
  hl("NvimCmdlineHintKeyLua", { fg = c.lavender, bold = true })
  hl("NvimCmdlineHintKeyShell", { fg = c.green, bold = true })
  hl("NvimCmdlineHintKeyOpts", { fg = c.teal, bold = true })
  hl("NvimCmdlineHintKeySubst", { fg = c.orange, bold = true })
  hl("NvimCmdlineHintKeyFilter", { fg = c.rose, bold = true })
  hl("NvimCmdlineHintKeyFile", { fg = c.lime, bold = true })
  hl("NvimCmdlineHintKeyHelp", { fg = c.blue, bold = true })
  hl("NvimCmdlineHintDesc", { fg = c.sub })
  hl("NvimCmdlineHintSep", { fg = c.dim }) -- │ between pairs
  hl("NvimCmdlineHintPad", { fg = c.dim }) -- leading/trailing space
  -- Macro recording indicator shown inside the hint line
  hl("NvimCmdlineMacroRec", { fg = c.red, bold = true })
  -- Fallback single-string hint highlight (backwards compat)
  hl("NvimCmdlineHint", { fg = c.dim, italic = true })

  -- ── Search counter ─────────────────────────────────────────────────────────
  hl("NvimCmdlineCounter", { fg = c.green, bold = true })
  hl("NvimCmdlineCounterTotal", { fg = c.sub })
  hl("NvimCmdlineCounterNone", { fg = c.dim, italic = true })
  hl("NvimCmdlineCounterSep", { fg = c.dim })
  hl("NvimCmdlineCounterChip", { fg = c.fg, bg = c.chip_bg, bold = true })
  hl("NvimCmdlineCounterChipEmpty", { fg = c.dim, bg = c.chip_bg_soft, italic = true })

  -- ── Register-paste transient indicator ────────────────────────────────────
  hl("NvimCmdlineRegister", { fg = c.lavender, bold = true })

  -- ── Title accent segments (border title only) ─────────────────────────────
  -- These highlights are ONLY passed to the floating-window title segment API
  -- (nvim_open_win / nvim_win_set_config title field).  They are never used
  -- as buffer extmark or winhighlight groups, so their bg cannot bleed.
  hl("NvimCmdlineTitleIconCmd", { fg = c.cyan, bg = c.tbg_cmd, bold = true })
  hl("NvimCmdlineTitleTextCmd", { fg = c.fg2, bg = c.tbg_cmd })
  hl("NvimCmdlineTitleIconSearch", { fg = c.amber, bg = c.tbg_search, bold = true })
  hl("NvimCmdlineTitleTextSearch", { fg = c.fg2, bg = c.tbg_search })
  hl("NvimCmdlineTitleIconLua", { fg = c.lavender, bg = c.tbg_lua, bold = true })
  hl("NvimCmdlineTitleTextLua", { fg = c.fg2, bg = c.tbg_lua })
  hl("NvimCmdlineTitleIconShell", { fg = c.green, bg = c.tbg_shell, bold = true })
  hl("NvimCmdlineTitleTextShell", { fg = c.fg2, bg = c.tbg_shell })
  hl("NvimCmdlineTitleIconHelp", { fg = c.blue, bg = c.tbg_help, bold = true })
  hl("NvimCmdlineTitleTextHelp", { fg = c.fg2, bg = c.tbg_help })
  hl("NvimCmdlineTitleIconOpts", { fg = c.teal, bg = c.tbg_opts, bold = true })
  hl("NvimCmdlineTitleTextOpts", { fg = c.fg2, bg = c.tbg_opts })
  hl("NvimCmdlineTitleIconSubst", { fg = c.orange, bg = c.tbg_subst, bold = true })
  hl("NvimCmdlineTitleTextSubst", { fg = c.fg2, bg = c.tbg_subst })
  hl("NvimCmdlineTitleIconFilter", { fg = c.rose, bg = c.tbg_filter, bold = true })
  hl("NvimCmdlineTitleTextFilter", { fg = c.fg2, bg = c.tbg_filter })
  hl("NvimCmdlineTitleIconFile", { fg = c.lime, bg = c.tbg_file, bold = true })
  hl("NvimCmdlineTitleTextFile", { fg = c.fg2, bg = c.tbg_file })

  -- ── Completion popup ──────────────────────────────────────────────────────
  hl("NvimCmdlineMenu", { fg = c.fg2, bg = c.popup_bg })
  hl("NvimCmdlineMenuBorder", { fg = c.border_dim, bg = c.popup_bg })
  hl("NvimCmdlineMenuSel", { fg = c.fg, bg = c.sel_bg, bold = true })
  hl("NvimCmdlineMenuMatch", { fg = c.green2, bg = c.popup_bg, bold = true })
  hl("NvimCmdlineMenuSelMatch", { fg = c.green, bg = c.sel_bg, bold = true })
  hl("NvimCmdlineMenuHint", { fg = c.dim, bg = c.popup_bg, italic = true })
  hl("NvimCmdlineMenuSelHint", { fg = c.cyan2, bg = c.sel_bg, italic = true })
  hl("NvimCmdlineMenuIcon", { fg = c.cyan2, bg = c.popup_bg })
  hl("NvimCmdlineMenuSelIcon", { fg = c.green, bg = c.sel_bg, bold = true })
  hl("NvimCmdlineMenuMark", { fg = c.border_glow, bg = c.popup_bg, bold = true })
  hl("NvimCmdlineMenuSelMark", { fg = c.green, bg = c.sel_bg, bold = true })

  -- Kind badge fallback
  hl("NvimCmdlineKindBadge", { fg = c.cyan, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindBadgeSel", { fg = c.green, bg = c.kind_sel_bg, bold = true })

  -- Per-kind accent colours (unselected rows only)
  hl("NvimCmdlineKindCmd", { fg = c.cyan, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindFile", { fg = c.lime, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindDir", { fg = c.amber, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindOpt", { fg = c.teal, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindHelp", { fg = c.blue, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindLua", { fg = c.lavender, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindShell", { fg = c.green, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindBuf", { fg = c.sub, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindColor", { fg = c.pink, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindEvt", { fg = c.orange, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindHl", { fg = c.rose, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindMap", { fg = c.lavender, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindSubst", { fg = c.orange, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindGbl", { fg = c.rose, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindReg", { fg = c.green, bg = c.kind_bg, italic = true })
  hl("NvimCmdlineKindExpr", { fg = c.lavender, bg = c.kind_bg, italic = true })

  -- ── Scrollbar ─────────────────────────────────────────────────────────────
  hl("NvimCmdlineScrollThumb", { fg = c.scroll_thumb, bg = c.popup_bg })
  hl("NvimCmdlineScrollTrack", { fg = c.scroll_track, bg = c.popup_bg })
  hl("NvimCmdlineMenuFooter", { fg = c.dim, bg = c.popup_bg, italic = true })

  -- ── Output / error floats ─────────────────────────────────────────────────
  hl("NvimCmdlineOutput", { fg = c.fg2, bg = c.muted_bg })
  hl("NvimCmdlineOutputBorder", { fg = c.border_dim, bg = c.muted_bg })
  hl("NvimCmdlineError", { fg = c.rose, bg = c.muted_bg })

  -- ── Live preview extmarks ─────────────────────────────────────────────────
  hl("NvimCmdlinePreviewDel", { fg = c.red, bg = c.preview_del_bg, strikethrough = true })
  hl("NvimCmdlinePreviewAdd", { fg = c.green, bg = c.preview_add_bg })
  hl("NvimCmdlinePreviewLine", { bg = c.preview_del_bg })
  hl("NvimCmdlinePreviewYank", { bg = c.preview_add_bg })

  -- ── Buffer-info footer ────────────────────────────────────────────────────
  hl("NvimCmdlineBufInfoFile", { fg = c.cyan, bg = c.bg, bold = true })
  hl("NvimCmdlineBufInfoFileSearch", { fg = c.amber, bg = c.bg, bold = true })
  hl("NvimCmdlineBufInfoFt", { fg = c.fg2, bg = c.bg })
  hl("NvimCmdlineBufInfoMeta", { fg = c.sub, bg = c.bg })
  hl("NvimCmdlineBufInfoMod", { fg = c.amber, bg = c.bg, bold = true })
  hl("NvimCmdlineBufInfoRO", { fg = c.rose, bg = c.bg, bold = true })
  hl("NvimCmdlineBufInfoSep", { fg = c.border_dim, bg = c.bg })
  hl("NvimCmdlineBufInfoRange", { fg = c.lavender, bg = c.bg, bold = true })
  hl("NvimCmdlineBufInfoIcon", { fg = c.dim, bg = c.bg })
  hl("NvimCmdlineBufInfoChip", { fg = c.sub, bg = c.chip_bg_soft, bold = true })
end

function M.setup_preview_highlights()
  -- All preview highlights are defined in setup_highlights().
end

return M
