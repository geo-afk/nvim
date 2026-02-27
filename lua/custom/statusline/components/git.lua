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
local hl = require('custom.statusline.highlights').hl

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
  for line in raw:gmatch '[^\n]+' do
    local x, y = line:sub(1, 1), line:sub(2, 2)
    if x == '?' then
      added = added + 1
    elseif x == 'A' or y == 'A' then
      added = added + 1
    elseif x == 'D' or y == 'D' then
      removed = removed + 1
    elseif x ~= ' ' or y ~= ' ' then
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

  async_cmd({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }, cwd, function(branch_raw)
    if not branch_raw then
      M.cache[cwd] = { branch = nil, added = 0, modified = 0, removed = 0, ts = now }
      M.redraw_fn() -- surgical, no bang
      return
    end
    local branch = branch_raw:gsub('%s+$', '')
    async_cmd({ 'git', 'status', '--porcelain' }, cwd, function(status_raw)
      local a, m, r = parse_status(status_raw)
      M.cache[cwd] = { branch = branch, added = a, modified = m, removed = r, ts = uv.now() }
      M.redraw_fn() -- surgical, no bang
    end)
  end)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------
function M.update(cwd)
  if cwd and cwd ~= '' then
    refresh(cwd)
  end
end

function M.render(winid)
  local win_width = vim.api.nvim_win_get_width(winid)
  local compact = win_width < 80

  local cwd = vim.fn.getcwd()
  local entry = M.cache[cwd]

  if not entry then
    refresh(cwd)
    return ''
  end
  if not entry.branch then
    return ''
  end

  local branch_str = hl 'StatusLineGitBranch' .. ' ' .. entry.branch .. hl 'StatusLine'

  if compact then
    return '  ' .. branch_str
  end

  local parts = { branch_str }
  if entry.added > 0 then
    parts[#parts + 1] = hl 'StatusLineGitAdd' .. '  ' .. entry.added .. hl 'StatusLine'
  end
  if entry.modified > 0 then
    parts[#parts + 1] = hl 'StatusLineGitMod' .. ' 󰦒 ' .. entry.modified .. hl 'StatusLine'
  end
  if entry.removed > 0 then
    parts[#parts + 1] = hl 'StatusLineGitDel' .. '  ' .. entry.removed .. hl 'StatusLine'
  end

  return '  ' .. table.concat(parts, ' ')
end

return M
