-- nvim-cmdline/colors.lua
-- Derives highlight groups from the active colorscheme.
-- Refreshed on every ColorScheme event.

local M = {}

local function int_to_hex(n)
  if type(n) ~= "number" then
    return nil
  end
  return string.format("#%06x", n)
end

local function get_hl(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return (ok and type(hl) == "table") and hl or {}
end

function M.get_colors()
  local normal = get_hl("Normal")
  local nfloat = get_hl("NormalFloat")
  local fborder = get_hl("FloatBorder")
  local comment = get_hl("Comment")
  local pmenusel = get_hl("PmenuSel")
  local pmenu = get_hl("Pmenu")
  local srch = get_hl("Search")
  local special = get_hl("Special")
  local string_h = get_hl("String")
  local keyword = get_hl("Keyword")
  local func_h = get_hl("Function")
  local type_h = get_hl("Type")
  local diag_err = get_hl("DiagnosticError")
  local diag_wrn = get_hl("DiagnosticWarn")

  -- Float surface background (content area)
  local bg = int_to_hex(nfloat.bg) or int_to_hex(normal.bg) or "#1e1e2e"
  -- Editor background — used for FloatBorder.bg so rounded corners don't bleed
  -- the float surface colour outside the curve into the editor.
  local editor_bg = int_to_hex(normal.bg) -- may be nil (transparent terminal bg)

  local fg = int_to_hex(nfloat.fg) or int_to_hex(normal.fg) or "#cdd6f4"
  local popup_bg = int_to_hex(pmenu.bg) or bg
  local border = int_to_hex(fborder.fg) or int_to_hex(special.fg) or int_to_hex(keyword.fg) or "#89b4fa"
  local dim = int_to_hex(comment.fg) or "#6c7086"
  local sel_bg = int_to_hex(pmenusel.bg) or "#313244"
  local sel_fg = int_to_hex(pmenusel.fg) or fg
  local accent = int_to_hex(string_h.fg) or "#a6e3a1"
  local accent2 = int_to_hex(func_h.fg) or int_to_hex(type_h.fg) or border
  local search_bg = int_to_hex(srch.bg) or "#f9e2af"
  local search_fg = int_to_hex(srch.fg) or "#1e1e2e"
  local err = int_to_hex(diag_err.fg) or "#f38ba8"
  local warn = int_to_hex(diag_wrn.fg) or "#fab387"

  return {
    bg = bg,
    fg = fg,
    editor_bg = editor_bg,
    popup_bg = popup_bg,
    border = border,
    dim = dim,
    sel_bg = sel_bg,
    sel_fg = sel_fg,
    accent = accent,
    accent2 = accent2,
    search_bg = search_bg,
    search_fg = search_fg,
    err = err,
    warn = warn,
  }
end

function M.setup_highlights()
  local c = M.get_colors()

  -- Border groups: bg = editor_bg (not float surface) so rounded corners
  -- (╭╮╯╰) don't bleed the float colour outside the curve.
  -- When editor_bg is nil (transparent terminal bg), omit it entirely so
  -- the corners are fully transparent.
  local function border_opts(fg_col, extra)
    local opts = vim.tbl_extend("force", { fg = fg_col }, extra or {})
    if c.editor_bg then
      opts.bg = c.editor_bg
    end
    return opts
  end

  local groups = {
    -- ── Main cmdline window ───────────────────────────────────────────────
    NvimCmdlineNormal = { fg = c.fg, bg = c.bg },
    NvimCmdlineBorder = border_opts(c.border),
    NvimCmdlineFloatTitle = { fg = c.border, bg = c.bg, bold = true },
    NvimCmdlineSearchBorder = border_opts(c.accent),
    NvimCmdlineSearchTitle = { fg = c.accent, bg = c.bg, bold = true },

    -- Badge: icon strip left of the │ separator
    NvimCmdlineBadge = { fg = c.border, bg = c.popup_bg, bold = true },
    NvimCmdlineBadgeSearch = { fg = c.accent, bg = c.popup_bg, bold = true },
    NvimCmdlineSep = { fg = c.dim, bg = c.bg },
    NvimCmdlinePrompt = { fg = c.border, bg = c.bg, bold = true },
    NvimCmdlineHint = { fg = c.dim, bg = c.bg, italic = true },

    -- ── Search counter ────────────────────────────────────────────────────
    NvimCmdlineCounter = { fg = c.accent, bg = c.bg, bold = true },
    NvimCmdlineCounterNone = { fg = c.dim, bg = c.bg, italic = true },

    -- ── Completion popup ──────────────────────────────────────────────────
    NvimCmdlineMenu = { fg = c.fg, bg = c.popup_bg },
    NvimCmdlineMenuBorder = border_opts(c.dim, { bg = c.editor_bg or c.popup_bg }),
    NvimCmdlineMenuSel = { fg = c.sel_fg, bg = c.sel_bg, bold = true },
    NvimCmdlineMenuMatch = { fg = c.accent, bg = c.popup_bg, bold = true },
    NvimCmdlineMenuSelMatch = { fg = c.accent, bg = c.sel_bg, bold = true },
    NvimCmdlineMenuHint = { fg = c.dim, bg = c.popup_bg, italic = true },
    NvimCmdlineMenuSelHint = { fg = c.border, bg = c.sel_bg, italic = true },
    NvimCmdlineMenuMark = { fg = c.border, bg = c.sel_bg, bold = true },

    -- ── Output / error float ──────────────────────────────────────────────
    NvimCmdlineOutput = { fg = c.fg, bg = c.bg },
    NvimCmdlineOutputBorder = border_opts(c.dim),
    NvimCmdlineError = { fg = c.err, bg = c.bg },
    NvimCmdlineWarn = { fg = c.warn, bg = c.bg },
  }

  for name, opts in pairs(groups) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

function M.setup_preview_highlights()
  for name, mod in pairs(package.loaded) do
    if name:match("%.preview$") and type(mod) == "table" and type(mod.setup_highlights) == "function" then
      mod.setup_highlights()
      break
    end
  end
end

return M
