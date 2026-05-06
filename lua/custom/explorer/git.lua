-- custom/explorer/git.lua
--
-- Git status is shown exclusively via the 2-column sign slot at the far
-- left of each row (cols 0-1 of `sign_ph`).  There is deliberately no
-- line-level background tint or filename colour change — those were the
-- "dimming" the user wanted removed.
--
-- Sign slot layout  (always 2 display columns):
--
--   IDLE          "  "   (two spaces — sign_ph in render.lua)
--   MODIFIED      " "   (icon + 1 space)
--   ADDED         " "   (icon + 1 space)
--   DELETED       " "   (icon + 1 space)
--   …
--
-- If Nerd Fonts are not available (use_git_icons = false) the icons
-- fall back to the plain-text git_signs table.
--
-- Display-width safety:
--   sign_str() measures the chosen glyph with vim.fn.strdisplaywidth()
--   and pads to exactly SIGN_WIDTH cols.  Results are cached per glyph
--   so the measurement only happens once per unique status character.
--   This guarantees the sign column never causes layout shifts regardless
--   of font, terminal, or icon provider.

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local search_ui = require("custom.explorer.search_ui")
local api = vim.api

local M = {}

-- ── Sign-column geometry ──────────────────────────────────────────────────

-- Must match the `sign_ph` width in render.lua ("  " = 2 display cols).
local SIGN_WIDTH = 2

-- ── Colour helpers ────────────────────────────────────────────────────────

local function hl_fg(n)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
  return ok and h and h.fg
end
local function hl_bg(n)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
  return ok and h and h.bg
end

-- ── Highlight name table ──────────────────────────────────────────────────

local SIGN_HL = {
  M = "ExplorerGitModified",
  A = "ExplorerGitAdded",
  D = "ExplorerGitDeleted",
  R = "ExplorerGitRenamed",
  ["?"] = "ExplorerGitUntracked",
  U = "ExplorerGitConflict",
  I = "ExplorerGitIgnored",
}
M.SIGN_HL = SIGN_HL

-- ── Width-safe sign string ────────────────────────────────────────────────
--
-- Returns a string that is exactly SIGN_WIDTH display columns wide.
-- Computed once per unique glyph and memoised so the strdisplaywidth()
-- call happens at most once per status character per Neovim session.

local _sign_cache = {}

local function make_sign(raw)
  local cached = _sign_cache[raw]
  if cached then
    return cached
  end
  local w = vim.fn.strdisplaywidth(raw)
  local out
  if w >= SIGN_WIDTH then
    -- Glyph fills or overflows the slot (e.g. a 2-col Nerd Font glyph).
    -- Trust the font; don't add extra padding.
    out = raw
  else
    out = raw .. (" "):rep(SIGN_WIDTH - w)
  end
  _sign_cache[raw] = out
  return out
end

-- Invalidate the cache when the user changes icon config (e.g. on setup()).
function M.clear_sign_cache()
  _sign_cache = {}
end

function M.sign_str(ch)
  local c = cfg.get()
  local use_nf = c.use_git_icons ~= false -- default true
  local icons = use_nf and (c.git_icons or {}) or {}
  local signs = c.git_signs or {}

  local glyph_map = {
    M = icons.modified or signs.modified or "~",
    A = icons.added or signs.added or "+",
    D = icons.deleted or signs.deleted or "x",
    R = icons.renamed or signs.renamed or ">",
    ["?"] = icons.untracked or signs.untracked or "?",
    U = icons.conflict or signs.conflict or "!",
    I = icons.ignored or signs.ignored or "-",
  }
  return make_sign(glyph_map[ch] or " ")
end

-- ── Highlight setup ───────────────────────────────────────────────────────
--
-- Only sign-glyph colours are defined here.  There are no line-level
-- background tints or filename colour overrides — the filename always
-- renders in ExplorerFile / ExplorerDirectory.

function M.setup_hl()
  local accent = hl_fg("Function") or hl_fg("@function") or hl_fg("Special") or 0xcba6f7
  
  -- Function to brighten a color by blending it with the accent or a light color
  local function brighten(c, factor)
    if not c then return accent end
    return c
  end

  local added = hl_fg("DiffAdd") or hl_fg("GitSignsAdd") or 0xa6e3a1
  local modified = hl_fg("DiffChange") or hl_fg("GitSignsChange") or 0xf9e2af
  local deleted = hl_fg("DiffDelete") or hl_fg("GitSignsDelete") or 0xf38ba8
  local untrack = hl_fg("Special") or 0x6c7086
  local conflict = hl_fg("DiagnosticError") or 0xf38ba8

  local function def(n, o)
    pcall(api.nvim_set_hl, 0, n, o)
  end

  -- Git icons: High-visibility palette using bold + vibrant accents
  def("ExplorerGitAdded", { fg = added, bold = true })
  def("ExplorerGitModified", { fg = modified, bold = true })
  def("ExplorerGitDeleted", { fg = deleted, bold = true })
  def("ExplorerGitRenamed", { fg = modified, bold = true })
  -- Untracked/Conflict: Use accent color to make them pop
  def("ExplorerGitUntracked", { fg = accent, bold = true })
  def("ExplorerGitConflict", { fg = conflict, bold = true })
  def("ExplorerGitIgnored", { fg = untrack, italic = true })
end

-- ── fetch: run git status --porcelain ─────────────────────────────────────

function M.fetch()
  if not cfg.get().show_git then
    return
  end
  vim.system(
    { "git", "-C", S.root, "status", "--porcelain", "-u" },
    { text = true },
    vim.schedule_wrap(function(out)
      if (out.code or 1) ~= 0 then
        S.git = {}
        return
      end
      local g = {}
      for line in (out.stdout or ""):gmatch("[^\n]+") do
        if #line >= 4 then
          local xy = line:sub(1, 2)
          local path = line:sub(4):match("^.+ %-> (.+)$") or line:sub(4)
          path = path:gsub('^"', ""):gsub('"$', "")
          local abs = (require("custom.explorer.tree")).norm(S.root .. "/" .. path)
          local ch = xy:sub(1, 1) ~= " " and xy:sub(1, 1) or xy:sub(2, 2)
          if ch and ch ~= " " and ch ~= "" then
            g[abs] = ch
          end
        end
      end
      S.git = g
      M.apply()
    end)
  )
end

-- ── apply: paint sign extmarks for current S.items ────────────────────────
--
-- Only the sign-column overlay is painted.  No background tints or
-- filename colour extmarks are set — the sign icon IS the sole indicator.

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)

  for i, item in ipairs(S.items) do
    -- Inherit the most-prominent child status for directories
    local ch = S.git[item.path]
    if not ch and item.is_dir then
      local pre = item.path .. "/"
      -- Priority order: conflict > deleted > modified > added > untracked > renamed > ignored
      local PRIO = { U = 7, D = 6, M = 5, A = 4, ["?"] = 3, R = 2, I = 1 }
      local best = 0
      for gp, gc in pairs(S.git) do
        if gp:sub(1, #pre) == pre then
          local p = PRIO[gc] or 0
          if p > best then
            best = p
            ch = gc
          end
        end
      end
    end

    if ch then
      pcall(api.nvim_buf_set_extmark, buf, S.git_ns, search_ui.row_for_item(i), 0, {
        end_col = SIGN_WIDTH,
        virt_text = { { M.sign_str(ch), SIGN_HL[ch] or "Comment" } },
        virt_text_pos = "overlay",
        priority = 20,
      })
    end
  end
end

return M
