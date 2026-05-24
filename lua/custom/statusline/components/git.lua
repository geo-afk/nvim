-- =============================================================================
-- statusline/components/git.lua  (flash-free revision)
-- =============================================================================
--
-- FLASH FIX: the async callback used `vim.cmd("redrawstatus!")` (bang).
-- That forced a full redraw of all statuslines. Replaced with
-- M.redraw_fn() — a reference injected by init.lua that calls the surgical
-- nvim__redraw or no-bang redrawstatus. Same data, no flash.
-- =============================================================================

local M = {}
local hl = require("custom.statusline.highlights").hl
local utils = require("custom.statusline.utils")

-- Injected by init.lua after setup (avoids circular require and gives us
-- the same debounced, surgical redraw path as every other component).
M.redraw_fn = function() end

-- ---------------------------------------------------------------------------
-- Cache: { [cwd] = { branch, added, modified, removed, ts } }
-- ---------------------------------------------------------------------------
M.cache = {}

local REFRESH_THROTTLE_MS = 1500
local uv = vim.uv or vim.loop

-- ---------------------------------------------------------------------------
-- Async helpers
-- ---------------------------------------------------------------------------
local function async_cmd(cmd, cwd, cb)
  local stdout = uv.new_pipe(false)
  local chunks = {}
  local handle
  handle = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    cwd = cwd,
    stdio = { nil, stdout, nil },
  }, function(code)
    stdout:close()
    handle:close()
    vim.schedule(function()
      cb(code == 0 and table.concat(chunks) or nil)
    end)
  end)

  if not handle then
    stdout:close()
    vim.schedule(function()
      cb(nil)
    end)
    return
  end

  stdout:read_start(function(_, data)
    if data then
      chunks[#chunks + 1] = data
    end
  end)
end

local function parse_status(raw)
  local added, modified, removed = 0, 0, 0
  if not raw then
    return added, modified, removed
  end
  for line in raw:gmatch("[^\n]+") do
    local x, y = line:sub(1, 1), line:sub(2, 2)
    if x == "?" then
      -- Untracked files - count as added
      added = added + 1
    elseif x == "A" or y == "A" then
      -- Added files
      added = added + 1
    elseif x == "D" or y == "D" then
      -- Deleted files
      removed = removed + 1
    elseif x == "M" or y == "M" or x == "R" or y == "R" or x == "C" or y == "C" then
      -- Modified, renamed, or copied files
      modified = modified + 1
    end
  end
  return added, modified, removed
end

local function refresh(cwd)
  local entry = M.cache[cwd]
  local now = uv.now()
  if entry and entry.ts and (now - entry.ts) < REFRESH_THROTTLE_MS then
    return
  end

  M.cache[cwd] = M.cache[cwd] or {}
  M.cache[cwd].ts = now

  async_cmd({ "git", "status", "--porcelain=v1", "--branch" }, cwd, function(status_raw)
    if not status_raw then
      M.cache[cwd] = { branch = nil, state = nil, added = 0, modified = 0, removed = 0, ts = now }
      M.redraw_fn() -- surgical, no bang
      return
    end
    local first = status_raw:match("([^\n]+)") or ""
    local branch = first:match("^## ([^%.%s]+)") or first:match("^## No commits yet on ([^%s]+)")
    local state = nil
    if first:find("HEAD %(no branch%)") or first:find("HEAD detached") then
      state = "DETACHED"
      branch = "HEAD"
    elseif first:find("rebase", 1, true) then
      state = "REBASE"
    elseif first:find("merge", 1, true) then
      state = "MERGE"
    end
    local body = status_raw:gsub("^[^\n]*\n?", "")
    local a, m, r = parse_status(body)
    M.cache[cwd] = { branch = branch, state = state, added = a, modified = m, removed = r, ts = uv.now() }
    M.redraw_fn() -- surgical, no bang
  end)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------
function M.update(cwd)
  if cwd and cwd ~= "" then
    refresh(cwd)
  end
end

function M.render(winid, width)
  local win_width = width or vim.api.nvim_win_get_width(winid)

  local cwd = vim.fn.getcwd()
  local entry = M.cache[cwd]

  if not entry then
    refresh(cwd)
    return ""
  end
  if not entry.branch then
    return ""
  end

  local branch_icon = win_width > 60 and "  " or ""
  local branch_str = hl("StatusLineGitBranch") .. branch_icon .. entry.branch .. " " .. hl("StatusLine")

  if win_width < 85 then
    return branch_str
  end

  local parts = { branch_str }
  if entry.added > 0 then
    parts[#parts + 1] = hl("StatusLineGitAdd") .. "  " .. entry.added .. " " .. hl("StatusLine")
  end
  if entry.modified > 0 then
    parts[#parts + 1] = hl("StatusLineGitMod") .. " 󰦒 " .. entry.modified .. " " .. hl("StatusLine")
  end
  if entry.removed > 0 then
    parts[#parts + 1] = hl("StatusLineGitDel") .. "  " .. entry.removed .. " " .. hl("StatusLine")
  end

  return utils.join(parts, " ")
end

local function diff_parts(entry)
  local parts = {}
  if entry.added > 0 then
    parts[#parts + 1] = hl("StatusLineGitAdd") .. " " .. entry.added .. hl("StatusLine")
  end
  if entry.modified > 0 then
    parts[#parts + 1] = hl("StatusLineGitMod") .. "󰦒 " .. entry.modified .. hl("StatusLine")
  end
  if entry.removed > 0 then
    parts[#parts + 1] = hl("StatusLineGitDel") .. " " .. entry.removed .. hl("StatusLine")
  end
  return parts
end

function M.variants(ctx)
  local cwd = vim.fn.getcwd()
  local entry = M.cache[cwd]
  if not entry then
    refresh(cwd)
    return {}
  end
  if not entry.branch then
    return {}
  end

  local state = entry.state and (hl("StatusLineGitMod") .. " " .. entry.state .. hl("StatusLine")) or ""
  local diffs = diff_parts(entry)
  local full_branch = hl("StatusLineGitBranch") .. " " .. entry.branch .. hl("StatusLine")
  local compact_branch = hl("StatusLineGitBranch")
    .. " "
    .. utils.compact_branch(entry.branch, 18)
    .. hl("StatusLine")
  local icon = hl("StatusLineGitBranch") .. "" .. hl("StatusLine")
  local diff_full = utils.join(diffs, " ")
  local diff_icon = (#diffs > 0) and (hl("StatusLineGitMod") .. "±" .. hl("StatusLine")) or ""

  return {
    { name = "full", text = utils.join({ full_branch, state, diff_full }, " ") },
    { name = "compact", text = utils.join({ compact_branch, state, diff_icon }, " ") },
    { name = "icon", text = utils.join({ icon, diff_icon }, " ") },
  }
end

return M
