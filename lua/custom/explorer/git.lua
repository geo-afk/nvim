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

  -- ── Diff stat colours (right-aligned +N -M on modified files) ────────────
  def("ExplorerGitStatAdd", { fg = added })
  def("ExplorerGitStatDel", { fg = deleted })
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

-- ── fetch: run git status --porcelain and git diff --numstat ─────────────
--
-- Two git processes are spawned concurrently (status + numstat).  A simple
-- barrier (pending counter) fires apply() once both have returned.
--
-- numstat covers both unstaged changes (vs working tree) and staged changes
-- (vs HEAD), so we run:
--   git diff         --numstat          (unstaged)
--   git diff --cached --numstat         (staged)
-- and merge the two, summing added/removed counts per file so a file with
-- both staged and unstaged changes shows the combined total.
--
-- Debounced: multiple calls within 100 ms collapse into one invocation set.

local _fetch_timer = nil

-- Namespace for stat extmarks (separate from git_ns / sign slot)
local STAT_NS = api.nvim_create_namespace("explorer_git_stat")
M.STAT_NS = STAT_NS

local function parse_numstat(stdout, root, out_tbl)
  local tree_mod = require("custom.explorer.tree")
  for line in (stdout or ""):gmatch("[^\n]+") do
    -- format: <added>\t<removed>\t<path>  (binary files show "-")
    local a, r, path = line:match("^(%S+)\t(%S+)\t(.+)$")
    if a and r and path then
      path = path:gsub('^"', ""):gsub('"$', "")
      -- Renames: "old => new" or "src/{old => new}/rest"
      path = path:match("{.+ => (.+)}") or path:match(".+ => (.+)") or path
      local abs = tree_mod.norm(root .. "/" .. path)
      local na = tonumber(a) or 0
      local nr = tonumber(r) or 0
      local cur = out_tbl[abs]
      if cur then
        cur.added = cur.added + na
        cur.removed = cur.removed + nr
      else
        out_tbl[abs] = { added = na, removed = nr }
      end
    end
  end
end

function M.fetch()
  if not cfg.get().show_git then
    return
  end
  if not is_git_repo(S.root) then
    return
  end

  if _fetch_timer then
    _fetch_timer:stop()
    _fetch_timer = nil
  end

  _fetch_timer = vim.defer_fn(function()
    _fetch_timer = nil

    local root = S.root
    local pending = 3 -- status + diff (unstaged) + diff --cached (staged)
    local new_git = {}
    local new_stats = {}

    local function maybe_done()
      pending = pending - 1
      if pending ~= 0 then
        return
      end
      if root ~= S.root then
        return
      end -- root changed while git ran

      -- ── Pre-compute directory status map ─────────────────────────────
      local tree_mod = require("custom.explorer.tree")
      local dir_status = {}
      for abs, ch in pairs(new_git) do
        local dir = tree_mod.parent(abs)
        local ch_prio = PRIO[ch] or 0
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

      S.git = new_git
      S.git_dirs = dir_status
      S.git_stats = new_stats
      M.apply()
    end

    -- ── 1. git status --porcelain ────────────────────────────────────────
    vim.system(
      { "git", "-C", root, "status", "--porcelain", "-u" },
      { text = true },
      vim.schedule_wrap(function(out)
        if (out.code or 1) == 0 then
          local tree_mod = require("custom.explorer.tree")
          for line in (out.stdout or ""):gmatch("[^\n]+") do
            if #line >= 4 then
              local xy = line:sub(1, 2)
              local path = line:sub(4):match("^.+ %-> (.+)$") or line:sub(4)
              path = path:gsub('^"', ""):gsub('"$', "")
              local abs = tree_mod.norm(root .. "/" .. path)
              local ch = xy:sub(1, 1) ~= " " and xy:sub(1, 1) or xy:sub(2, 2)
              if ch and ch ~= " " and ch ~= "" then
                new_git[abs] = ch
              end
            end
          end
        end
        maybe_done()
      end)
    )

    -- ── 2. git diff --numstat (unstaged) ─────────────────────────────────
    vim.system(
      { "git", "-C", root, "diff", "--numstat" },
      { text = true },
      vim.schedule_wrap(function(out)
        if (out.code or 1) == 0 then
          parse_numstat(out.stdout, root, new_stats)
        end
        maybe_done()
      end)
    )

    -- ── 3. git diff --cached --numstat (staged) ───────────────────────────
    vim.system(
      { "git", "-C", root, "diff", "--cached", "--numstat" },
      { text = true },
      vim.schedule_wrap(function(out)
        if (out.code or 1) == 0 then
          parse_numstat(out.stdout, root, new_stats)
        end
        maybe_done()
      end)
    )
  end, 100)
end

-- ── apply: paint sign extmarks and diff stats for current S.items ─────────
--
-- Sign slot: O(1) per item via S.git / S.git_dirs table lookups.
-- Diff stats: right-aligned "+N -M" virtual text for files with numstat data.
--   • Only file rows get stats (directories show the status icon only).
--   • Files with zero added AND zero removed (e.g. chmod-only) are skipped.
--   • Priority 18 — below git sign (20) but above base tree (10), so the
--     stat doesn't compete with the sign glyph visually.

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)
  api.nvim_buf_clear_namespace(buf, STAT_NS, 0, -1)

  local git_dirs = S.git_dirs or {}
  local stats = S.git_stats or {}
  local set_em = require("custom.ui.render").set_extmark

  for i, item in ipairs(S.items) do
    local ch = S.git[item.path]
    if not ch and item.is_dir then
      ch = git_dirs[item.path]
    end

    local row = search_ui.row_for_item(i)

    -- ── Sign glyph ────────────────────────────────────────────────────────
    if ch then
      pcall(set_em, buf, S.git_ns, row, 0, {
        end_col = SIGN_WIDTH,
        virt_text = { { M.sign_str(ch), SIGN_HL[ch] or "Comment" } },
        virt_text_pos = "overlay",
        priority = 20,
      })
    end

    -- ── Diff stat (files only, not directories, not deleted/untracked) ─────
    if not item.is_dir and ch and ch ~= "D" and ch ~= "I" then
      local st = stats[item.path]
      if st and (st.added > 0 or st.removed > 0) then
        local chunks = {}
        if st.added > 0 then
          chunks[#chunks + 1] = { "+" .. st.added, "ExplorerGitStatAdd" }
        end
        if st.added > 0 and st.removed > 0 then
          chunks[#chunks + 1] = { " ", "Comment" }
        end
        if st.removed > 0 then
          chunks[#chunks + 1] = { "-" .. st.removed, "ExplorerGitStatDel" }
        end
        pcall(set_em, buf, STAT_NS, row, 0, {
          virt_text = chunks,
          virt_text_pos = "right_align",
          priority = 18,
        })
      end
    end
  end
end

return M
