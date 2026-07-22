-- custom/explorer/diagnostics.lua
--
-- Adds folder-level diagnostic severity badges to the explorer tree.
--
-- Design (per audit preference: "Folder-level severity badges only"):
--
--   Each *directory* node gets a right-aligned virtual-text badge showing
--   the highest-severity diagnostic among all files under it:
--
--     ╰─  src/           ●
--         ├─  api/
--         │   ╰─  foo.ts
--         ╰─  utils/
--
--   File nodes are intentionally left unlabelled to keep rows uncluttered.
--   If you later want per-file icons, change the `item.is_dir` guard in apply().
--
-- Implementation notes:
--
--   • Uses vim.diagnostic.get(nil) — returns diagnostics across ALL buffers.
--     Only buffers that are currently loaded have diagnostics; unloaded files
--     will not show badges until opened.  This is intentional: it avoids
--     running a whole-project diagnostic scan.
--
--   • DiagnosticChanged fires very frequently during LSP indexing.  A 300 ms
--     debounce collapses rapid bursts into a single apply() pass.
--
--   • The namespace "explorer_diag" is separate from git/marks so clear+reapply
--     has no cross-contamination risk.
--
--   • apply() is called from render._paint() and render._paint_items_only()
--     after git and marks have been applied, so badge priority (15) sits between
--     the base tree highlights (10) and git signs (20).  Adjust priority if
--     you want badges to dominate.

local S = require("custom.explorer.state")
local search_ui = require("custom.explorer.search_ui")
local api = vim.api
local fn = vim.fn

local M = {}

-- ── Namespace ─────────────────────────────────────────────────────────────

local NS = api.nvim_create_namespace("explorer_diag")

-- ── Severity config ───────────────────────────────────────────────────────
--
-- Priority: ERROR (1) > WARN (2) > INFO (3) > HINT (4).
-- PRIO maps vim.diagnostic severity integers to a rank so we can compare them.

local SEVERITY_PRIO = { [1] = 4, [2] = 3, [3] = 2, [4] = 1 }

-- Nerd Font icons — fall back to plain text if use_nerd_icons is false in
-- your config, but these are the same icons already used by your sign column.
local SEVERITY_ICON = {
  [1] = "", -- ERROR  nf-fa-times_circle
  [2] = "", -- WARN   nf-fa-exclamation_triangle
  [3] = "", -- INFO   nf-fa-info_circle
  [4] = "󰌵", -- HINT   nf-cod-lightbulb
}

local SEVERITY_HL = {
  [1] = "DiagnosticError",
  [2] = "DiagnosticWarn",
  [3] = "DiagnosticInfo",
  [4] = "DiagnosticHint",
}

-- ── Status map builder ────────────────────────────────────────────────────
--
-- Returns two tables:
--   file_sev[abs_path]  → highest severity integer for that file
--   dir_sev[abs_path]   → highest severity bubbled up from children
--
-- Only loaded buffers contribute; this is a live-diagnostics view, not a
-- whole-workspace scan.

local function build_severity_maps()
  local root = S.root or ""
  local file_sev = {}

  for _, d in ipairs(vim.diagnostic.get(nil)) do
    local bufname = api.nvim_buf_get_name(d.bufnr)
    if bufname and bufname ~= "" then
      local sev = d.severity
      local cur = file_sev[bufname]
      if not cur or (SEVERITY_PRIO[sev] or 0) > (SEVERITY_PRIO[cur] or 0) then
        file_sev[bufname] = sev
      end
    end
  end

  -- Bubble up to ancestor directories up to (but not above) S.root
  local dir_sev = {}
  for path, sev in pairs(file_sev) do
    local sev_prio = SEVERITY_PRIO[sev] or 0
    local dir = fn.fnamemodify(path, ":h")
    while dir and #dir >= #root do
      local cur = dir_sev[dir]
      if not cur or sev_prio > (SEVERITY_PRIO[cur] or 0) then
        dir_sev[dir] = sev
      end
      local parent = fn.fnamemodify(dir, ":h")
      if parent == dir then
        break
      end -- reached filesystem root
      dir = parent
    end
  end

  return file_sev, dir_sev
end

-- ── apply ─────────────────────────────────────────────────────────────────
--
-- Paints right-aligned severity badge virtual text on directory rows.
-- Called from render._paint() and render._paint_items_only().

function M.apply()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  if not S.items or #S.items == 0 then
    return
  end

  local file_sev, dir_sev = build_severity_maps()

  for i, item in ipairs(S.items) do
    local sev
    if item.is_dir then
      sev = dir_sev[item.path]
    else
      -- Uncomment the line below to add per-file icons too:
      -- sev = file_sev[item.path]
    end

    if sev then
      pcall(require("custom.ui.render").set_extmark, buf, NS, search_ui.row_for_item(i), 0, {
        virt_text = { { SEVERITY_ICON[sev], SEVERITY_HL[sev] } },
        virt_text_pos = "right_align",
        priority = 15,
      })
    end
  end
end

-- ── schedule_apply ────────────────────────────────────────────────────────
--
-- Debounced wrapper for the DiagnosticChanged autocmd.
-- 300 ms is long enough to collapse LSP indexing storms; short enough that
-- the badges feel responsive once the user saves a file.

local _debounce_timer = nil

function M.schedule_apply()
  if _debounce_timer then
    _debounce_timer:stop()
    _debounce_timer = nil
  end
  _debounce_timer = vim.defer_fn(function()
    _debounce_timer = nil
    if S.buf and api.nvim_buf_is_valid(S.buf) then
      M.apply()
    end
  end, 300)
end

-- ── setup ─────────────────────────────────────────────────────────────────
--
-- Call once from init.lua:M.setup().  Registers the DiagnosticChanged
-- autocmd globally; the apply() function itself guards on S.buf validity.

function M.setup()
  api.nvim_create_autocmd("DiagnosticChanged", {
    group = api.nvim_create_augroup("ExplorerDiagnostics", { clear = true }),
    desc = "explorer: refresh diagnostic badges",
    callback = function()
      M.schedule_apply()
    end,
  })
end

return M
