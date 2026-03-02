-- custom/explorer/git.lua
-- S.items[i] → 0-based row = i  (header is row 0, item 1 is row 1)

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local api = vim.api

local M = {}

local function blend(fg, bg, a)
  local function lerp(f, b)
    return math.floor(f * a + b * (1 - a) + 0.5)
  end
  return lerp(math.floor(fg / 0x10000) % 0x100, math.floor(bg / 0x10000) % 0x100) * 0x10000
    + lerp(math.floor(fg / 0x100) % 0x100, math.floor(bg / 0x100) % 0x100) * 0x100
    + lerp(fg % 0x100, bg % 0x100)
end

local function hl_fg(n)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
  return ok and h and h.fg
end
local function hl_bg(n)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
  return ok and h and h.bg
end

local SIGN_HL = {
  M = 'ExplorerGitModified',
  A = 'ExplorerGitAdded',
  D = 'ExplorerGitDeleted',
  R = 'ExplorerGitRenamed',
  ['?'] = 'ExplorerGitUntracked',
  U = 'ExplorerGitConflict',
  I = 'ExplorerGitIgnored',
}
local LINE_HL = {
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

function M.sign_str(ch)
  local s = cfg.get().git_signs
  local m = {
    M = s.modified or '~',
    A = s.added or '+',
    D = s.deleted or '✗',
    R = s.renamed or '→',
    ['?'] = s.untracked or '?',
    U = s.conflict or '!',
    I = s.ignored or '◌',
  }
  return (m[ch] or ' ') .. ' '
end

function M.setup_hl()
  local added = hl_fg 'DiffAdd' or hl_fg 'GitSignsAdd' or 0xa8e6cf
  local modified = hl_fg 'DiffChange' or hl_fg 'GitSignsChange' or 0xffcb8e
  local deleted = hl_fg 'DiffDelete' or hl_fg 'GitSignsDelete' or 0xff6b9d
  local untrack = hl_fg 'Comment' or 0x7a8899
  local conflict = hl_fg 'DiagnosticError' or 0xff5555
  local sbg = hl_bg 'ExplorerNormal' or hl_bg 'NormalFloat' or hl_bg 'Normal' or 0x1e2030
  local A, AD = 0.13, 0.20

  local function def(n, o)
    pcall(api.nvim_set_hl, 0, n, o)
  end
  def('ExplorerGitAdded', { fg = added, bold = true })
  def('ExplorerGitModified', { fg = modified, bold = true })
  def('ExplorerGitDeleted', { fg = deleted, bold = true })
  def('ExplorerGitRenamed', { fg = modified, bold = true })
  def('ExplorerGitUntracked', { fg = untrack })
  def('ExplorerGitConflict', { fg = conflict, bold = true })
  def('ExplorerGitIgnored', { fg = untrack, italic = true })

  def('ExplorerGitAddedLine', { fg = added, bg = blend(added, sbg, A) })
  def('ExplorerGitModifiedLine', { fg = modified, bg = blend(modified, sbg, A) })
  def('ExplorerGitDeletedLine', { fg = deleted, bg = blend(deleted, sbg, AD), strikethrough = true })
  def('ExplorerGitRenamedLine', { fg = modified, bg = blend(modified, sbg, A) })
  def('ExplorerGitUntrackedLine', { fg = untrack, bg = blend(untrack, sbg, A) })
  def('ExplorerGitConflictLine', { fg = conflict, bg = blend(conflict, sbg, A), bold = true })
  def('ExplorerGitIgnoredLine', { fg = untrack, bg = blend(untrack, sbg, A), italic = true })
end

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
      local g = {}
      for line in (out.stdout or ''):gmatch '[^\n]+' do
        if #line >= 4 then
          local xy = line:sub(1, 2)
          local path = line:sub(4):match '^.+ %-> (.+)$' or line:sub(4)
          path = path:gsub('^"', ''):gsub('"$', '')
          local abs = (require('custom.explorer.tree').norm)(S.root .. '/' .. path)
          local ch = xy:sub(1, 1) ~= ' ' and xy:sub(1, 1) or xy:sub(2, 2)
          if ch and ch ~= ' ' and ch ~= '' then
            g[abs] = ch
          end
        end
      end
      S.git = g
      M.apply()
    end)
  )
end

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)
  for i, item in ipairs(S.items) do
    local ch = S.git[item.path]
    if not ch and item.is_dir then
      local pre = item.path .. '/'
      for gp, gc in pairs(S.git) do
        if gp:sub(1, #pre) == pre then
          ch = gc
          break
        end
      end
    end
    if ch then
      -- S.items[i] → 0-based row = i  (row 0 = search bar, row 1 = items[1])
      local row = i
      pcall(api.nvim_buf_set_extmark, buf, S.git_ns, row, 0, {
        end_col = 2,
        virt_text = { { M.sign_str(ch), SIGN_HL[ch] or 'Comment' } },
        virt_text_pos = 'overlay',
        priority = 20,
      })
      if item._col_name then
        pcall(api.nvim_buf_set_extmark, buf, S.git_ns, row, item._col_name, {
          end_col = item._col_name_end,
          hl_group = LINE_HL[ch] or 'Normal',
          hl_eol = true,
          priority = 15,
        })
      end
    end
  end
end

return M
