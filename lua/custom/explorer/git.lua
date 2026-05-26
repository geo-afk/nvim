-- custom/explorer/git.lua
--
-- Git status is shown exclusively via the 2-column sign slot at the far
-- left of each row (cols 0-1 of `sign_ph`).  There is deliberately no
-- line-level background tint or filename colour change.
--
-- Sign slot layout  (always 2 display columns):
--
--   IDLE          "  "   (two spaces — sign_ph in render.lua)
--   MODIFIED      " "   (icon + 1 space)
--   ADDED         " "   (icon + 1 space)
--   …
--
-- Fixes applied vs original:
--
--  1. O(n×m) directory status scan eliminated — the original apply() looped
--     over every git-tracked path for every directory item, doing an O(m)
--     string prefix test per combination.  The new fetch() pre-computes
--     S.git_dirs (path → highest-priority child status) once when git output
--     is parsed.  apply() then does O(1) table lookups per item.
--
--  2. Debounced fetch() — multiple rapid calls (file-watcher storms, keymap
--     refresh) no longer spawn concurrent git processes.  A 100 ms debounce
--     collapses bursts into a single git invocation.
--
--  3. _is_git_cache per root — avoids spawning `git status` in directories
--     that are not git repositories.  The cache is invalidated when S.root
--     changes (called from init.lua:M.open()).

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local search_ui = require("custom.explorer.search_ui")
local api = vim.api

local M = {}

-- ── Sign-column geometry ──────────────────────────────────────────────────

-- Must match the `sign_ph` width in render.lua ("  " = 2 display cols).
local SIGN_WIDTH = 2

-- ── Status priority (conflict > deleted > modified > added > …) ───────────

local PRIO = { U = 7, D = 6, M = 5, A = 4, ["?"] = 3, R = 2, I = 1 }

-- ── Colour helpers ────────────────────────────────────────────────────────

local function hl_fg(n)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = n, link = false })
  return ok and h and h.fg
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
-- Computed once per unique glyph and memoised.

local _sign_cache = {}

local function make_sign(raw)
  local cached = _sign_cache[raw]
  if cached then
    return cached
  end
  local w = vim.fn.strdisplaywidth(raw)
  local out = w >= SIGN_WIDTH and raw or (raw .. (" "):rep(SIGN_WIDTH - w))
  _sign_cache[raw] = out
  return out
end

function M.clear_sign_cache()
  _sign_cache = {}
end

function M.sign_str(ch)
  local c = cfg.get()
  local use_nf = c.use_git_icons ~= false
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

function M.setup_hl()
  local accent = hl_fg("Function") or hl_fg("@function") or hl_fg("Special") or 0xcba6f7
  local added = hl_fg("DiffAdd") or hl_fg("GitSignsAdd") or 0xa6e3a1
  local modified = hl_fg("DiffChange") or hl_fg("GitSignsChange") or 0xf9e2af
  local deleted = hl_fg("DiffDelete") or hl_fg("GitSignsDelete") or 0xf38ba8
  local untrack = hl_fg("Special") or 0x6c7086
  local conflict = hl_fg("DiagnosticError") or 0xf38ba8

  local function def(n, o)
    pcall(api.nvim_set_hl, 0, n, o)
  end

  def("ExplorerGitAdded", { fg = added, bold = true })
  def("ExplorerGitModified", { fg = modified, bold = true })
  def("ExplorerGitDeleted", { fg = deleted, bold = true })
  def("ExplorerGitRenamed", { fg = modified, bold = true })
  def("ExplorerGitUntracked", { fg = accent, bold = true })
  def("ExplorerGitConflict", { fg = conflict, bold = true })
  def("ExplorerGitIgnored", { fg = untrack, italic = true })
end

-- ── Git-repo cache ────────────────────────────────────────────────────────
--
-- Avoids spawning `git status` when the explorer is opened in a non-git dir.
-- Keyed by root path.  Invalidated when the root changes (see M.invalidate_repo_cache).

local _is_git_cache = {}

local function is_git_repo(root)
  local cached = _is_git_cache[root]
  if cached ~= nil then
    return cached
  end
  local ok = vim.uv.fs_stat(root .. "/.git") ~= nil
  _is_git_cache[root] = ok
  return ok
end

-- Called from init.lua when S.root changes to a new value.
function M.invalidate_repo_cache(root)
  if root then
    _is_git_cache[root] = nil
  end
end

-- ── fetch: run git status --porcelain ─────────────────────────────────────
--
-- Debounced: multiple calls within 100 ms collapse into one git invocation.
-- Pre-computes S.git_dirs (directory → worst child status) so apply() can
-- do O(1) lookups instead of the old O(n×m) prefix scan.

local _fetch_timer = nil

function M.fetch()
  if not cfg.get().show_git then
    return
  end
  if not is_git_repo(S.root) then
    return
  end

  -- Debounce: collapse rapid bursts (file-watcher, multi-keymap refresh)
  if _fetch_timer then
    _fetch_timer:stop()
    _fetch_timer = nil
  end

  _fetch_timer = vim.defer_fn(function()
    _fetch_timer = nil

    -- Snapshot root at call time; guard against root change before callback fires
    local root = S.root

    vim.system(
      { "git", "-C", root, "status", "--porcelain", "-u" },
      { text = true },
      vim.schedule_wrap(function(out)
        -- Root may have changed while git was running; discard stale results
        if root ~= S.root then
          return
        end

        if (out.code or 1) ~= 0 then
          S.git = {}
          S.git_dirs = {}
          return
        end

        local tree_mod = require("custom.explorer.tree")
        local g = {}

        for line in (out.stdout or ""):gmatch("[^\n]+") do
          if #line >= 4 then
            local xy = line:sub(1, 2)
            local path = line:sub(4):match("^.+ %-> (.+)$") or line:sub(4)
            path = path:gsub('^"', ""):gsub('"$', "")
            local abs = tree_mod.norm(root .. "/" .. path)
            local ch = xy:sub(1, 1) ~= " " and xy:sub(1, 1) or xy:sub(2, 2)
            if ch and ch ~= " " and ch ~= "" then
              g[abs] = ch
            end
          end
        end

        -- ── Pre-compute directory status map ─────────────────────────────
        --
        -- Walk every changed file up to S.root, propagating the highest-
        -- priority status to each ancestor directory.  This replaces the
        -- O(n×m) per-item prefix scan that was previously in apply().
        local dir_status = {}
        for abs, ch in pairs(g) do
          local dir = tree_mod.parent(abs)
          local ch_prio = PRIO[ch] or 0
          -- Walk up but stop at or above root
          while dir and #dir >= #root do
            local cur = dir_status[dir]
            if not cur or ch_prio > (PRIO[cur] or 0) then
              dir_status[dir] = ch
            end
            local parent = tree_mod.parent(dir)
            if parent == dir then
              break
            end
            dir = parent
          end
        end

        S.git = g
        S.git_dirs = dir_status
        M.apply()
      end)
    )
  end, 100)
end

-- ── apply: paint sign extmarks for current S.items ────────────────────────
--
-- O(1) per item — reads S.git (file status) and S.git_dirs (pre-computed
-- directory status) with simple table lookups.

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)

  local git_dirs = S.git_dirs or {}

  for i, item in ipairs(S.items) do
    local ch = S.git[item.path]
    if not ch and item.is_dir then
      ch = git_dirs[item.path]
    end

    if ch then
      pcall(require("custom.ui.render").set_extmark, buf, S.git_ns, search_ui.row_for_item(i), 0, {
        end_col = SIGN_WIDTH,
        virt_text = { { M.sign_str(ch), SIGN_HL[ch] or "Comment" } },
        virt_text_pos = "overlay",
        priority = 20,
      })
    end
  end
end

return M
