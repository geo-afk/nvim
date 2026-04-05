-- =============================================================================
-- statusline/highlights.lua  (dynamic colorscheme edition)
-- =============================================================================
--
-- STRATEGY
-- ────────
-- 1. Read colors FROM the active colorscheme via nvim_get_hl(0,{link=false}).
--    `link=false` forces Neovim to follow any `link=` chain and return the
--    actual resolved fg/bg integer, not just the link target name.
-- 2. Try a priority list of groups per role (e.g. for "error" we try
--    DiagnosticError → ErrorMsg → Error).  First non-nil color wins.
-- 3. Fall back to the hardcoded FALLBACK_PALETTE only if the colorscheme
--    defines no color at all for that role.
-- 4. setup() is idempotent — call it on ColorScheme event to retheme live.
--
-- Result: the statusline naturally adapts to any installed colorscheme
-- (tokyonight, catppuccin, gruvbox, nord, dracula, kanagawa, rose-pine …)
-- while still looking correct with no colorscheme at all.
-- =============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Fallback palette — used only when the colorscheme omits a given color.
-- These values match a generic dark-mode aesthetic.
-- ---------------------------------------------------------------------------
local FALLBACK = {
  -- Backgrounds
  bg = '#1e1e2e',
  bg_dim = '#181825',
  bg_alt = '#313244',
  bg_chip = '#26293a',

  -- Mode colours (fallback when colorscheme Function/String/Keyword are unset)
  normal = '#89b4fa', -- blue
  insert = '#a6e3a1', -- green
  visual = '#cba6f7', -- purple
  replace = '#f38ba8', -- red
  command = '#f9e2af', -- yellow
  terminal = '#94e2d5', -- teal
  select = '#fab387', -- orange

  -- Foreground tiers
  fg = '#cdd6f4',
  fg_dim = '#6c7086',
  fg_muted = '#45475a',
  fg_on_accent = '#1e1e2e', -- text on bright pill background

  -- Accent (accent on top of statusline bg)
  accent = '#89b4fa',
  separator = '#45475a',
  fill = '#313244',

  -- Semantic colors
  git_add = '#a6e3a1',
  git_mod = '#f9e2af',
  git_del = '#f38ba8',
  git_branch = '#cba6f7',

  diag_error = '#f38ba8',
  diag_warn = '#f9e2af',
  diag_hint = '#94e2d5',
  diag_info = '#89dceb',

  lsp_active = '#a6e3a1',
  lsp_loading = '#f9e2af',

  modified = '#f38ba8',
  readonly = '#f9e2af',
  filesize = '#94e2d5',
  encoding = '#89dceb',
  line_count = '#cba6f7',
  bufnr = '#6c7086',
  progress = '#89b4fa',
  macro = '#fab387',
  paste = '#94e2d5',
  spell_color = '#cba6f7',
  wrap_color = '#89dceb',
  os_icon = '#cdd6f4',
  cwd_color = '#6c7086',
  ruler_fill = '#89b4fa',
  ruler_empty = '#45475a',
}

-- ---------------------------------------------------------------------------
-- Color extraction helpers
-- ---------------------------------------------------------------------------

--- Get fg or bg from a highlight group as a "#rrggbb" string.
--- Returns nil if the group is undefined or the attribute is unset.
local function hl_color(group, attr)
  local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not def then
    return nil
  end
  local val = def[attr]
  if not val or val == 0 then
    return nil
  end
  return string.format('#%06x', val)
end

--- Try groups in order; return the first non-nil color found.
local function first_color(group_list, attr)
  for _, g in ipairs(group_list) do
    local c = hl_color(g, attr)
    if c then
      return c
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Build a dynamic palette from the active colorscheme.
-- ---------------------------------------------------------------------------
local function build_palette()
  -- ── Base ──────────────────────────────────────────────────────────────────
  -- "Normal" defines the editor canvas.  For the statusline background we
  -- prefer whatever the colorscheme sets for StatusLine; if it's unset we
  -- use Normal bg slightly darkened (we can't darken in pure Lua here so
  -- we just use Normal bg as a reasonable default).
  local normal_bg = hl_color('Normal', 'bg') or FALLBACK.bg
  local normal_fg = hl_color('Normal', 'fg') or FALLBACK.fg
  local sl_bg = hl_color('StatusLine', 'bg') or normal_bg
  local sl_nc_bg = hl_color('StatusLineNC', 'bg') or FALLBACK.bg_dim
  local comment = hl_color('Comment', 'fg') or FALLBACK.fg_dim
  local nontext = hl_color('NonText', 'fg') or FALLBACK.fg_muted

  -- ── Mode colours ──────────────────────────────────────────────────────────
  -- We map each mode to a semantically appropriate syntax group:
  --   Normal  → Function  (blue accent — most colorschemes)
  --   Insert  → String    (green — broadly conventional)
  --   Visual  → Keyword   (purple/magenta — broadly conventional)
  --   Replace → Error / DiagnosticError (red)
  --   Command → WarningMsg / DiagnosticWarn (yellow)
  --   Terminal→ Special / Character (teal/cyan)
  --   Select  → Constant / Number (orange)
  local c_normal = first_color({ '@function', 'Function', '@lsp.type.function' }, 'fg') or FALLBACK.normal
  local c_insert = first_color({ 'String', '@string', '@string.special' }, 'fg') or FALLBACK.insert
  local c_visual = first_color({ 'Keyword', '@keyword', 'Statement' }, 'fg') or FALLBACK.visual
  local c_replace = first_color({ 'DiagnosticError', 'ErrorMsg', 'Error' }, 'fg') or FALLBACK.replace
  local c_command = first_color({ 'DiagnosticWarn', 'WarningMsg', 'Todo' }, 'fg') or FALLBACK.command
  local c_terminal = first_color({ 'Special', '@character.special', 'SpecialChar' }, 'fg') or FALLBACK.terminal
  local c_select = first_color({ 'Constant', '@constant', 'Number' }, 'fg') or FALLBACK.select

  -- ── Diagnostics ───────────────────────────────────────────────────────────
  local d_err = first_color({ 'DiagnosticError', 'DiagnosticSignError', 'ErrorMsg' }, 'fg') or FALLBACK.diag_error
  local d_warn = first_color({ 'DiagnosticWarn', 'DiagnosticSignWarn', 'WarningMsg' }, 'fg') or FALLBACK.diag_warn
  local d_hint = first_color({ 'DiagnosticHint', 'DiagnosticSignHint' }, 'fg') or FALLBACK.diag_hint
  local d_info = first_color({ 'DiagnosticInfo', 'DiagnosticSignInfo' }, 'fg') or FALLBACK.diag_info

  -- ── Git diff ──────────────────────────────────────────────────────────────
  -- Priority: GitSigns (fg) > diff syntax (fg) > DiffAdd (bg, since many
  -- colorschemes only set a background tint on DiffAdd, not a fg).
  local g_add = first_color({ 'GitSignsAdd', 'diffAdded', 'Added' }, 'fg') or hl_color('DiffAdd', 'bg') or FALLBACK.git_add
  local g_mod = first_color({ 'GitSignsChange', 'diffChanged', 'Changed' }, 'fg') or hl_color('DiffChange', 'bg') or FALLBACK.git_mod
  local g_del = first_color({ 'GitSignsDelete', 'diffRemoved', 'Removed' }, 'fg') or hl_color('DiffDelete', 'bg') or FALLBACK.git_del
  local g_branch = first_color({ '@keyword', 'Keyword', 'PreProc', 'Special' }, 'fg') or FALLBACK.git_branch

  -- ── Accent / separator ────────────────────────────────────────────────────
  local accent = first_color({ '@function', 'Function', 'Identifier' }, 'fg') or FALLBACK.accent
  local separator = comment or FALLBACK.separator

  -- ── Cursor / position ─────────────────────────────────────────────────────
  local cursor_bg = hl_color('CursorLine', 'bg') or FALLBACK.bg_alt
  local pmenu_bg = hl_color('Pmenu', 'bg') or FALLBACK.bg_chip

  -- ── Specials ──────────────────────────────────────────────────────────────
  local macro_bg = first_color({ 'Constant', '@constant', 'Number' }, 'fg') or FALLBACK.macro
  local paste_bg = first_color({ 'Special', '@string.special' }, 'fg') or FALLBACK.paste
  local spell_bg = first_color({ 'SpellBad', 'SpellLocal' }, 'fg') or FALLBACK.spell_color

  return {
    bg = sl_bg,
    bg_dim = sl_nc_bg,
    bg_alt = cursor_bg,
    bg_chip = pmenu_bg,
    fg = normal_fg,
    fg_dim = comment,
    fg_muted = nontext,
    fg_on_accent = FALLBACK.fg_on_accent, -- always dark (text on bright pill)

    normal = c_normal,
    insert = c_insert,
    visual = c_visual,
    replace = c_replace,
    command = c_command,
    terminal = c_terminal,
    select = c_select,

    diag_error = d_err,
    diag_warn = d_warn,
    diag_hint = d_hint,
    diag_info = d_info,

    git_add = g_add,
    git_mod = g_mod,
    git_del = g_del,
    git_branch = g_branch,

    lsp_active = first_color({ 'DiagnosticOk', 'DiagnosticHint' }, 'fg') or FALLBACK.lsp_active,
    lsp_loading = d_warn,

    accent = accent,
    separator = separator,
    fill = nontext or FALLBACK.fill,

    modified = d_err,
    readonly = d_warn,
    filesize = FALLBACK.filesize,
    encoding = FALLBACK.encoding,
    line_count = first_color({ '@keyword', 'Keyword' }, 'fg') or FALLBACK.line_count,
    bufnr = comment,
    progress = c_normal,
    ruler_fill = c_normal,
    ruler_empty = nontext,

    macro = macro_bg,
    paste = paste_bg,
    spell_c = spell_bg,
    wrap_c = accent,
    os_icon = normal_fg,
    cwd_c = comment,
  }
end

-- ---------------------------------------------------------------------------
-- Highlight group definitions  (composed after palette is built)
-- ---------------------------------------------------------------------------
local function define_groups(p)
  local groups = {
    -- ── Base ────────────────────────────────────────────────────────────────
    StatusLine = { fg = p.fg, bg = p.bg },
    StatusLineNC = { fg = p.fg_dim, bg = p.bg_dim },
    StatusLineSep = { fg = p.separator, bg = p.bg },
    StatusLineAlt = { fg = p.fg, bg = p.bg_alt },
    StatusLineChip = { fg = p.fg, bg = p.bg_chip },
    StatusLineChipMuted = { fg = p.fg_dim, bg = p.bg_chip },
    StatusLineFill = { fg = p.fill, bg = p.bg },

    -- ── Mode pills ──────────────────────────────────────────────────────────
    StatusLineNormal = { fg = p.fg_on_accent, bg = p.normal, bold = true },
    StatusLineInsert = { fg = p.fg_on_accent, bg = p.insert, bold = true },
    StatusLineVisual = { fg = p.fg_on_accent, bg = p.visual, bold = true },
    StatusLineReplace = { fg = p.fg_on_accent, bg = p.replace, bold = true },
    StatusLineCommand = { fg = p.fg_on_accent, bg = p.command, bold = true },
    StatusLineTerminal = { fg = p.fg_on_accent, bg = p.terminal, bold = true },
    StatusLineSelect = { fg = p.fg_on_accent, bg = p.select, bold = true },

    -- Powerline separators: fg = pill colour, bg = statusline bg
    StatusLineNormalSep = { fg = p.normal, bg = p.bg },
    StatusLineInsertSep = { fg = p.insert, bg = p.bg },
    StatusLineVisualSep = { fg = p.visual, bg = p.bg },
    StatusLineReplaceSep = { fg = p.replace, bg = p.bg },
    StatusLineCommandSep = { fg = p.command, bg = p.bg },
    StatusLineTermSep = { fg = p.terminal, bg = p.bg },
    StatusLineSelectSep = { fg = p.select, bg = p.bg },

    -- ── File ────────────────────────────────────────────────────────────────
    StatusLineFilePath = { fg = p.fg, bg = p.bg, bold = true },
    StatusLineFileIcon = { fg = p.accent, bg = p.bg },
    StatusLineModified = { fg = p.modified, bg = p.bg, bold = true },
    StatusLineReadonly = { fg = p.readonly, bg = p.bg, bold = true },
    StatusLineFileSize = { fg = p.filesize, bg = p.bg },
    StatusLineEncoding = { fg = p.encoding, bg = p.bg },
    StatusLineLineCount = { fg = p.line_count, bg = p.bg },
    StatusLineBufNr = { fg = p.bufnr, bg = p.bg },

    -- ── Git ─────────────────────────────────────────────────────────────────
    StatusLineGitBranch = { fg = p.git_branch, bg = p.bg, bold = true },
    StatusLineGitAdd = { fg = p.git_add, bg = p.bg },
    StatusLineGitMod = { fg = p.git_mod, bg = p.bg },
    StatusLineGitDel = { fg = p.git_del, bg = p.bg },

    -- ── LSP ─────────────────────────────────────────────────────────────────
    StatusLineLSPActive = { fg = p.lsp_active, bg = p.bg, bold = true },
    StatusLineLSPLoad = { fg = p.lsp_loading, bg = p.bg, bold = true },
    StatusLineLSPName = { fg = p.fg_dim, bg = p.bg },
    StatusLineDiagError = { fg = p.diag_error, bg = p.bg, bold = true },
    StatusLineDiagWarn = { fg = p.diag_warn, bg = p.bg },
    StatusLineDiagHint = { fg = p.diag_hint, bg = p.bg },
    StatusLineDiagInfo = { fg = p.diag_info, bg = p.bg },

    -- ── Cursor / progress ───────────────────────────────────────────────────
    StatusLineCursor = { fg = p.fg, bg = p.bg_chip, bold = true },
    StatusLineProgress = { fg = p.progress, bg = p.bg, bold = true },
    StatusLineRulerFill = { fg = p.ruler_fill, bg = p.bg },
    StatusLineRulerEmpty = { fg = p.ruler_empty, bg = p.bg },

    -- ── System / context ────────────────────────────────────────────────────
    StatusLineOS = { fg = p.os_icon, bg = p.bg },
    StatusLineCWD = { fg = p.cwd_c, bg = p.bg, italic = true },
    StatusLineMacro = { fg = p.fg_on_accent, bg = p.macro, bold = true },
    StatusLinePaste = { fg = p.fg_on_accent, bg = p.paste, bold = true },
    StatusLineSpell = { fg = p.fg_on_accent, bg = p.spell_c, bold = true },
    StatusLineWrap = { fg = p.wrap_c, bg = p.bg },

    -- ── Inactive ────────────────────────────────────────────────────────────
    StatusLineInactive = { fg = p.fg_muted, bg = p.bg_dim },
  }

  for name, def in pairs(groups) do
    local opts = {
      fg = def.fg,
      bg = def.bg,
      bold = def.bold or false,
      italic = def.italic or false,
      underline = def.underline or false,
    }
    vim.api.nvim_set_hl(0, name, opts)
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- (Re-)apply all highlight groups from the current colorscheme.
--- Call once at startup and again on ColorScheme events.
function M.setup()
  local palette = build_palette()
  define_groups(palette)
  -- Expose built palette for inspection / debugging
  M._palette = palette
end

--- Return the %#GroupName# statusline escape string.
function M.hl(name)
  return '%#' .. name .. '#'
end

return M
