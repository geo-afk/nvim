-- explorer/git.lua
-- Git status with full fg+bg highlights per status.
-- Signs are rendered as extmark overlays in the 2-char left placeholder;
-- the entire filename row is tinted with a blended background colour.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'

local M = {}

-- ── Colour helpers ────────────────────────────────────────────────────────

-- Blend `fg` colour into `bg` at `alpha` (0=pure bg, 1=pure fg).
-- All values are 24-bit integers (0xRRGGBB).  No bit library needed.
local function blend(fg_col, bg_col, alpha)
  local function lerp(f, b)
    return math.floor(f * alpha + b * (1 - alpha) + 0.5)
  end
  local fr = math.floor(fg_col / 0x10000) % 0x100
  local fg_ = math.floor(fg_col / 0x100) % 0x100
  local fb = fg_col % 0x100
  local br = math.floor(bg_col / 0x10000) % 0x100
  local bg_ = math.floor(bg_col / 0x100) % 0x100
  local bb = bg_col % 0x100
  return lerp(fr, br) * 0x10000 + lerp(fg_, bg_) * 0x100 + lerp(fb, bb)
end

-- Read fg or bg from a highlight group.  Returns nil if not set.
local function hl_fg(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return (ok and h) and h.fg or nil
end
local function hl_bg(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return (ok and h) and h.bg or nil
end

-- ── Highlight group names ─────────────────────────────────────────────────

local SIGN_HL = { -- bold icon in the 2-char left column
  M = 'ExplorerGitModified',
  A = 'ExplorerGitAdded',
  D = 'ExplorerGitDeleted',
  R = 'ExplorerGitRenamed',
  ['?'] = 'ExplorerGitUntracked',
  U = 'ExplorerGitConflict',
  I = 'ExplorerGitIgnored',
}

local LINE_HL = { -- full-line highlight (fg + tinted bg)
  M = 'ExplorerGitModifiedLine',
  A = 'ExplorerGitAddedLine',
  D = 'ExplorerGitDeletedLine',
  R = 'ExplorerGitRenamedLine',
  ['?'] = 'ExplorerGitUntrackedLine',
  U = 'ExplorerGitConflictLine',
  I = 'ExplorerGitIgnoredLine',
}

M.SIGN_HL = SIGN_HL
M.LINE_HL = LINE_HL

-- ── Sign glyph ────────────────────────────────────────────────────────────

function M.sign_str(ch)
  local signs = cfg.get().git_signs
  local map = {
    M = signs.modified or 'M',
    A = signs.added or 'A',
    D = signs.deleted or 'D',
    R = signs.renamed or 'R',
    ['?'] = signs.untracked or '?',
    U = signs.conflict or 'U',
    I = signs.ignored or 'I',
  }
  return (map[ch] or ' ') .. ' '
end

-- ── Highlight setup (called once + on ColorScheme) ────────────────────────
function M.setup_hl()
  -- Derive foreground colours from the active colorscheme.
  local added_fg = hl_fg 'DiffAdd' or hl_fg 'GitSignsAdd' or 0x00cc6a
  local modified_fg = hl_fg 'DiffChange' or hl_fg 'GitSignsChange' or 0xe0af68
  local deleted_fg = hl_fg 'DiffDelete' or hl_fg 'GitSignsDelete' or 0xf7768e
  local untracked_fg = hl_fg 'Comment' or 0x565f89
  local conflict_fg = hl_fg 'DiagnosticError' or 0xff5555
  local renamed_fg = modified_fg
  local ignored_fg = untracked_fg

  -- Sidebar background (what we blend status colours INTO).
  local sidebar_bg = hl_bg 'ExplorerNormal' or hl_bg 'NormalFloat' or hl_bg 'Normal' or 0x1a1b26 -- tokyonight-style fallback

  -- Background tint strength: 0.12 = very subtle, 0.20 = noticeable.
  -- Deleted files get a slightly stronger tint so the strikethrough reads well.
  local ALPHA = 0.13
  local ALPHA_DEL = 0.18

  local function def(name, opts)
    pcall(vim.api.nvim_set_hl, 0, name, opts)
  end

  -- ── Sign icon groups (bold, vivid — just the 2-char glyph column) ──────
  def('ExplorerGitAdded', { fg = added_fg, bold = true })
  def('ExplorerGitModified', { fg = modified_fg, bold = true })
  def('ExplorerGitDeleted', { fg = deleted_fg, bold = true })
  def('ExplorerGitRenamed', { fg = renamed_fg, bold = true })
  def('ExplorerGitUntracked', { fg = untracked_fg, bold = true })
  def('ExplorerGitConflict', { fg = conflict_fg, bold = true })
  def('ExplorerGitIgnored', { fg = ignored_fg })

  -- ── Full-line groups (fg = status colour, bg = blended tint) ───────────
  -- These are applied as hl_eol extmarks so the background extends to end-of-line.
  def('ExplorerGitAddedLine', { fg = added_fg, bg = blend(added_fg, sidebar_bg, ALPHA) })
  def('ExplorerGitModifiedLine', { fg = modified_fg, bg = blend(modified_fg, sidebar_bg, ALPHA) })
  def('ExplorerGitDeletedLine', { fg = deleted_fg, bg = blend(deleted_fg, sidebar_bg, ALPHA_DEL), strikethrough = true })
  def('ExplorerGitRenamedLine', { fg = renamed_fg, bg = blend(renamed_fg, sidebar_bg, ALPHA) })
  def('ExplorerGitUntrackedLine', { fg = untracked_fg, bg = blend(untracked_fg, sidebar_bg, ALPHA) })
  def('ExplorerGitConflictLine', { fg = conflict_fg, bg = blend(conflict_fg, sidebar_bg, ALPHA), bold = true })
  def('ExplorerGitIgnoredLine', { fg = ignored_fg, bg = blend(ignored_fg, sidebar_bg, ALPHA), italic = true })
end

-- ── Fetch git status ──────────────────────────────────────────────────────
function M.fetch()
  if not cfg.get().show_git then
    return
  end
  vim.system(
    { 'git', '-C', S.root, 'status', '--porcelain', '-u' },
    { text = true },
    vim.schedule_wrap(function(out)
      if (out.code or 1) ~= 0 then
        S.git = {}
        return
      end
      local git = {}
      for line in (out.stdout or ''):gmatch '[^\n]+' do
        if #line >= 4 then
          local xy = line:sub(1, 2)
          local path = line:sub(4)
          path = path:match '^.+ %-> (.+)$' or path
          path = path:gsub('^"', ''):gsub('"$', '')
          local abs = (require('custom.explorer.tree').norm)(S.root .. '/' .. path)
          local ch = xy:sub(1, 1) ~= ' ' and xy:sub(1, 1) or xy:sub(2, 2)
          if ch and ch ~= ' ' and ch ~= '' then
            git[abs] = ch
          end
        end
      end
      S.git = git
      M.apply()
    end)
  )
end

-- ── Apply extmarks ────────────────────────────────────────────────────────
-- Items map to buffer lines 2..N  (line 1 is the header).
-- 0-indexed buffer row for S.items[i]  =  i   (header is row 0, item 1 is row 1).
function M.apply()
  local buf = S.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)

  for i, item in ipairs(S.items) do
    -- Direct match or bubble from children for directories
    local ch = S.git[item.path]
    if not ch and item.is_dir then
      local prefix = item.path .. '/'
      for gpath, gch in pairs(S.git) do
        if gpath:sub(1, #prefix) == prefix then
          ch = gch
          break
        end
      end
    end
    if ch then
      local sign_hl = SIGN_HL[ch] or 'Comment'
      local line_hl = LINE_HL[ch] or 'Normal'
      local row = i -- 0-indexed: header=0, item[1]=1, item[2]=2, …

      -- 1. Sign glyph overlay on the 2-char placeholder
      pcall(vim.api.nvim_buf_set_extmark, buf, S.git_ns, row, 0, {
        end_col = 2,
        virt_text = { { M.sign_str(ch), sign_hl } },
        virt_text_pos = 'overlay',
        priority = 20,
      })

      -- 2. Full-row colour: fg + tinted bg, extends to end-of-line
      if item._col_name then
        pcall(vim.api.nvim_buf_set_extmark, buf, S.git_ns, row, item._col_name, {
          end_col = item._col_name_end,
          hl_group = line_hl,
          hl_eol = true, -- background extends to end of line
          priority = 15,
        })
      end
    end
  end
end

return M
