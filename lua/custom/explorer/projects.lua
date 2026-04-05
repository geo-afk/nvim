-- custom/explorer/projects.lua
-- Floating project switcher with live fuzzy-filter.
--
-- Layout (inside the floating window):
--
--   ╭──────────────── 󰉋 Projects ─────────────────╮
--   │  󰉋  jump to project…                         │  ← row 0  (search bar)
--   │  ──────────────────────────────────────────── │  ← virt_line separator
--   │  ► 󰊢 my-project      ~/dev/my-project        │  ← items start at row 1
--   │    󰊢 another-app     ~/dev/another-app        │
--   │    󰉋 plain-dir       ~/plain-dir              │
--   ╰────────────────────────────────────────────── ╯
--
-- Project sources (in priority order):
--   1. config.projects.dirs  – explicit paths, always shown
--   2. S.recent_roots        – directories opened as explorer roots this session
--   3. config.projects.roots – directories scanned one level deep for sub-dirs
--
-- Insert-mode keymaps (active the whole time the window is open):
--   <C-j> / <Down>   move selection down
--   <C-k> / <Up>     move selection up
--   <C-d>            move selection down 5
--   <C-u>            wipe filter text (stay in insert)
--   <CR>             open selected project as new explorer root
--   <Esc>            close without selecting
--   <BS>             blocked at icon-prefix boundary
--   <Tab> / <S-Tab>  blocked (no completion popup)

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local store = require("custom.explorer.project_store")
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop

local M = {}

-- ── Module-local window state ─────────────────────────────────────────────

local P = {
  buf = nil, -- scratch buffer
  win = nil, -- floating window
  projects = {}, -- full list  { path, name, is_git, pinned, recent, discovered }
  filtered = {}, -- filtered subset
  filter = "", -- current filter string
  cursor = 1, -- 1-based index into P.filtered (the "selected" item)
}

local _ns = api.nvim_create_namespace("explorer_projects")

-- Mirror render.lua constants so the search bar looks identical
local ICON_PREFIX = "     " -- 5 spaces (same width as the icon overlay)
local SEARCH_ICON = " 󰉋  " -- project-folder icon, 5-col overlay
local PLACEHOLDER = "jump to project…"
local EMPTY_GUIDE = "Add config.projects.dirs or config.projects.roots to populate this picker."
local is_git

local SOURCE_PRIORITY = {
  pinned = 1,
  recent = 2,
  discovered = 3,
}

local function project_source_label(p)
  if p.path == S.root then
    return "current"
  end
  if p.pinned then
    return "pinned"
  end
  if p.recent then
    return "recent"
  end
  return "found"
end

local function ensure_project(out, seen, path, source)
  local item = seen[path]
  if item then
    if source == "pinned" then
      item.pinned = true
    elseif source == "recent" then
      item.recent = true
      item.recent_index = item.recent_index or math.huge
    elseif source == "discovered" then
      item.discovered = true
    end
    return item
  end

  item = {
    path = path,
    name = fn.fnamemodify(path, ":t"),
    is_git = is_git(path),
    pinned = source == "pinned",
    recent = source == "recent",
    discovered = source == "discovered",
    missing = not store.exists(path),
    recent_index = math.huge,
  }
  seen[path] = item
  out[#out + 1] = item
  return item
end

local function project_base_rank(p)
  if p.path == S.root then
    return 0
  end
  if p.pinned then
    return SOURCE_PRIORITY.pinned
  end
  if p.recent then
    return SOURCE_PRIORITY.recent
  end
  return SOURCE_PRIORITY.discovered
end

local function compare_projects(a, b)
  local ar, br = project_base_rank(a), project_base_rank(b)
  if ar ~= br then
    return ar < br
  end
  if a.recent and b.recent and a.recent_index ~= b.recent_index then
    return a.recent_index < b.recent_index
  end
  local an, bn = a.name:lower(), b.name:lower()
  if an ~= bn then
    return an < bn
  end
  return a.path:lower() < b.path:lower()
end

local function fuzzy_score(text, query)
  if query == "" then
    return 1
  end

  local pos = 1
  local run = 0
  local score = 0

  for i = 1, #query do
    local ch = query:sub(i, i)
    local found = text:find(ch, pos, true)
    if not found then
      return nil
    end
    if found == pos then
      run = run + 1
      score = score + 8 + run
    else
      run = 0
      score = score + 2
    end
    pos = found + 1
  end

  return score - (#text - #query) * 0.1
end

local function match_project(p, filter_text)
  local q = vim.trim(filter_text:lower())
  if q == "" then
    return true, 0
  end

  local name = p.name:lower()
  local path = p.path:lower()
  local score = 0

  if name == q then
    score = score + 180
  elseif name:find(q, 1, true) == 1 then
    score = score + 120
  elseif name:find(q, 1, true) then
    score = score + 80
  end

  if path:find(q, 1, true) then
    score = score + 30
  end

  for token in q:gmatch("%S+") do
    if name:find(token, 1, true) then
      score = score + 25
    elseif path:find(token, 1, true) then
      score = score + 12
    else
      local name_fuzzy = fuzzy_score(name, token)
      local path_fuzzy = fuzzy_score(path, token)
      local best = math.max(name_fuzzy or -1, path_fuzzy or -1)
      if best < 0 then
        return false, 0
      end
      score = score + best
    end
  end

  if p.path == S.root then
    score = score + 40
  end
  if p.pinned then
    score = score + 18
  end
  if p.recent then
    score = score + math.max(1, 14 - math.min(p.recent_index or 99, 12))
  end

  return true, score
end

-- ── Project discovery ─────────────────────────────────────────────────────
is_git = function(path)
  return uv.fs_stat(path .. "/.git") ~= nil
end

--- Scan `root_dir` one level deep for subdirectories and append to `out`.
--- Calls `done()` when finished (async via uv.fs_scandir).
local function scan_root(root_dir, out, seen, done)
  uv.fs_scandir(
    root_dir,
    vim.schedule_wrap(function(err, handle)
      if err or not handle then
        done()
        return
      end
      local batch = {}
      while true do
        local name = uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if name:sub(1, 1) ~= "." then
          local abs = root_dir .. "/" .. name
          local st = uv.fs_stat(abs) -- resolves symlinks
          if st and st.type == "directory" then
            batch[#batch + 1] = { name = name, path = abs }
          end
        end
      end
      for _, e in ipairs(batch) do
        ensure_project(out, seen, e.path, "discovered")
      end
      done()
    end)
  )
end

--- Collect all configured projects then call on_done(list).
local function collect_projects(on_done)
  local pc = (cfg.current or cfg.defaults).projects or {}
  local out = {}
  local seen = {}

  -- 1. Persisted pinned + explicit dirs (highest priority, always shown first)
  local pinned = vim.list_extend(store.get_pinned(), pc.dirs or {})
  for _, raw in ipairs(pinned) do
    local p = fn.expand(raw)
    if not seen[p] then
      ensure_project(out, seen, p, "pinned")
    end
  end

  -- 2. Recent roots from persisted history + session activity
  local recent = vim.list_extend(store.get_recent(), S.recent_roots or {})
  for i, r in ipairs(recent) do
    if r and r ~= "" then
      local item = ensure_project(out, seen, r, "recent")
      item.recent = true
      item.recent_index = math.min(item.recent_index or math.huge, i)
    end
  end

  -- 3. Scan configured root directories (one level deep, async)
  local roots = pc.roots or {}
  local pending = #roots
  if pending == 0 then
    on_done(out)
    return
  end

  for _, raw in ipairs(roots) do
    scan_root(fn.expand(raw), out, seen, function()
      pending = pending - 1
      if pending == 0 then
        table.sort(out, compare_projects)
        on_done(out)
      end
    end)
  end
end

-- ── Filtering ─────────────────────────────────────────────────────────────

local function apply_filter()
  local f = P.filter
  P.filtered = {}
  for _, p in ipairs(P.projects) do
    local ok, score = match_project(p, f)
    if ok then
      p._match_score = score
      P.filtered[#P.filtered + 1] = p
    end
  end
  table.sort(P.filtered, function(a, b)
    if (a._match_score or 0) ~= (b._match_score or 0) then
      return (a._match_score or 0) > (b._match_score or 0)
    end
    return compare_projects(a, b)
  end)
  P.cursor = math.max(1, math.min(P.cursor, math.max(1, #P.filtered)))
end

-- ── Paint ─────────────────────────────────────────────────────────────────

local function win_width()
  if P.win and api.nvim_win_is_valid(P.win) then
    return api.nvim_win_get_width(P.win)
  end
  return 60
end

--- Redraw search-bar extmarks on row 0.  Does NOT rewrite buffer text.
local function paint_header()
  local buf = P.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, _ns, 0, 1) -- row 0 only

  local w = win_width()

  -- Background wash
  pcall(api.nvim_buf_set_extmark, buf, _ns, 0, 0, {
    end_col = -1,
    hl_group = "ExplorerSearchBgActive",
    hl_eol = true,
    priority = 5,
  })
  -- Icon overlay (covers ICON_PREFIX with a Nerd Font glyph)
  pcall(api.nvim_buf_set_extmark, buf, _ns, 0, 0, {
    virt_text = { { SEARCH_ICON, "ExplorerSearchIconActive" } },
    virt_text_pos = "overlay",
    priority = 100,
  })
  -- Placeholder shown when filter is empty
  if P.filter == "" then
    pcall(api.nvim_buf_set_extmark, buf, _ns, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  end
  -- Match-count badge (right-aligned, only when filter is active)
  if P.filter ~= "" then
    local n = #P.filtered
    local label = n == 0 and " no matches " or (" " .. n .. (n == 1 and " match " or " matches "))
    pcall(api.nvim_buf_set_extmark, buf, _ns, 0, 0, {
      virt_text = { { label, "ExplorerSearchCount" } },
      virt_text_pos = "right_align",
      priority = 70,
    })
  end
  -- Separator virt_line below the search bar
  pcall(api.nvim_buf_set_extmark, buf, _ns, 0, 0, {
    virt_lines = { { { ("─"):rep(w), "ExplorerSearchBorderActive" } } },
    priority = 100,
  })
end

--- Rewrite item lines (rows 1+) and their extmarks.
--- Safe to call while in insert mode on row 0 — does NOT touch line 1.
local function paint_items()
  local buf = P.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end

  local lines = {}
  local marks = {}

  if #P.projects == 0 then
    lines[1] = "   No projects discovered yet."
    lines[2] = "   " .. EMPTY_GUIDE
    marks[#marks + 1] = { kind = "hl", row = 1, cs = 3, ce = -1, hl = "Comment", eol = false, pri = 20 }
  elseif #P.filtered == 0 then
    lines[1] = '   No matches for "' .. P.filter .. '".'
    lines[2] = "   Try part of the project name or path."
    marks[#marks + 1] = { kind = "hl", row = 1, cs = 3, ce = -1, hl = "Comment", eol = false, pri = 20 }
  else
    for idx, p in ipairs(P.filtered) do
      local is_cur = (idx == P.cursor)
      local icon = p.is_git and "󰊢 " or "󰉋 "
      local short = fn.fnamemodify(p.path, ":~")
      local badge = "[" .. project_source_label(p) .. "]"
      local missing = p.missing and "  [missing]" or ""
      local line = "   " .. icon .. p.name .. "  " .. badge .. missing .. "  " .. short
      lines[#lines + 1] = line

      local row = idx
      local ico_s = 3
      local ico_e = ico_s + #icon
      local name_s = ico_e
      local name_e = name_s + #p.name
      local badge_s = name_e + 2
      local badge_e = badge_s + #badge
      local missing_s = badge_e
      local missing_e = badge_e
      if p.missing then
        missing_s = badge_e + 2
        missing_e = missing_s + #" [missing]"
      end
      local path_s = p.missing and (missing_e + 2) or (badge_e + 2)

      if is_cur then
        marks[#marks + 1] = { kind = "hl", row = row, cs = 0, ce = -1, hl = "ExplorerCursorLine", eol = true, pri = 10 }
        marks[#marks + 1] = { kind = "vt", row = row, col = 0, vt = { { "► ", "ExplorerDirectory" } }, pri = 30 }
      end

      marks[#marks + 1] = {
        kind = "hl",
        row = row,
        cs = ico_s,
        ce = ico_e,
        hl = p.is_git and "ExplorerGitAdded" or "ExplorerDirectory",
        pri = 20,
      }
      marks[#marks + 1] = {
        kind = "hl",
        row = row,
        cs = name_s,
        ce = name_e,
        hl = is_cur and "ExplorerDirectory" or "Normal",
        pri = 20,
      }
      marks[#marks + 1] = {
        kind = "hl",
        row = row,
        cs = badge_s,
        ce = badge_e,
        hl = p.path == S.root and "ExplorerDirectory" or "ExplorerSearchCount",
        pri = 20,
      }
      if p.missing then
        marks[#marks + 1] = {
          kind = "hl",
          row = row,
          cs = missing_s,
          ce = missing_e,
          hl = "Comment",
          pri = 20,
        }
      end
      if path_s < #line then
        marks[#marks + 1] = { kind = "hl", row = row, cs = path_s, ce = #line, hl = "Comment", pri = 20 }
      end
    end
  end

  -- Rewrite only rows 1+ (the search bar on row 0 is left alone)
  api.nvim_buf_set_lines(buf, 1, -1, false, lines)
  api.nvim_buf_clear_namespace(buf, _ns, 1, -1)

  for _, m in ipairs(marks) do
    if m.kind == "vt" then
      pcall(api.nvim_buf_set_extmark, buf, _ns, m.row, m.col, {
        virt_text = m.vt,
        virt_text_pos = "overlay",
        priority = m.pri,
      })
    elseif m.ce == -1 then
      pcall(api.nvim_buf_set_extmark, buf, _ns, m.row, m.cs, {
        end_col = -1,
        hl_group = m.hl,
        hl_eol = m.eol,
        priority = m.pri,
      })
    else
      pcall(api.nvim_buf_set_extmark, buf, _ns, m.row, m.cs, {
        end_col = m.ce,
        hl_group = m.hl,
        priority = m.pri,
      })
    end
  end
end

local function paint_all()
  paint_header()
  paint_items()
end

local function refresh_projects()
  collect_projects(vim.schedule_wrap(function(projects)
    if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
      return
    end
    P.projects = projects
    apply_filter()
    paint_all()
    if P.win and api.nvim_win_is_valid(P.win) and api.nvim_get_mode().mode:sub(1, 1) == "i" then
      pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
    end
  end))
end

-- ── Selection ─────────────────────────────────────────────────────────────

local function move_cursor(delta)
  if #P.filtered == 0 then
    return
  end
  P.cursor = math.max(1, math.min(#P.filtered, P.cursor + delta))
  paint_items()
  -- Keep the physical cursor on row 0 (the search bar) while typing
  if P.win and api.nvim_win_is_valid(P.win) then
    if api.nvim_get_mode().mode:sub(1, 1) == "i" then
      pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
    end
  end
end

local function open_selected()
  local p = P.filtered[P.cursor]
  M.close()
  if not p then
    return
  end

  -- Record the old root as a recent before switching
  if S.root then
    S.recent_roots = S.recent_roots or {}
    for i, r in ipairs(S.recent_roots) do
      if r == S.root then
        table.remove(S.recent_roots, i)
        break
      end
    end
    table.insert(S.recent_roots, 1, S.root)
    while #S.recent_roots > 20 do
      table.remove(S.recent_roots)
    end
    store.push_recent(S.root)
  end

  -- Open the explorer rooted at the chosen project
  vim.schedule(function()
    require("custom.explorer").open({ root = p.path })
  end)
end

local function current_project()
  return P.filtered[P.cursor]
end

local function toggle_pin_selected()
  local p = current_project()
  if not p then
    return
  end
  local pinned = store.toggle_pinned(p.path)
  vim.notify(
    pinned and ("[explorer] pinned project: " .. fn.fnamemodify(p.path, ":~"))
      or ("[explorer] unpinned project: " .. fn.fnamemodify(p.path, ":~")),
    vim.log.levels.INFO
  )
  refresh_projects()
end

local function remove_selected()
  local p = current_project()
  if not p then
    return
  end
  store.remove(p.path)
  for i, r in ipairs(S.recent_roots or {}) do
    if r == p.path then
      table.remove(S.recent_roots, i)
      break
    end
  end
  vim.notify("[explorer] removed project entry: " .. fn.fnamemodify(p.path, ":~"), vim.log.levels.INFO)
  refresh_projects()
end

-- ── Open / close ──────────────────────────────────────────────────────────

function M.close()
  if api.nvim_get_mode().mode:sub(1, 1) == "i" then
    vim.cmd("stopinsert")
  end
  if P.win and api.nvim_win_is_valid(P.win) then
    pcall(api.nvim_win_close, P.win, true)
  end
  if P.buf and api.nvim_buf_is_valid(P.buf) then
    pcall(api.nvim_buf_delete, P.buf, { force = true })
  end
  P.win = nil
  P.buf = nil
  P.filter = ""
  P.cursor = 1
  P.projects = {}
  P.filtered = {}
end

function M.open()
  -- Focus the window if it's already open
  if P.win and api.nvim_win_is_valid(P.win) then
    api.nvim_set_current_win(P.win)
    return
  end

  require("custom.explorer.win").ensure_hl()

  -- ── Buffer ──────────────────────────────────────────────────────────
  local buf = api.nvim_create_buf(false, true)
  P.buf = buf
  P.filter = ""
  P.cursor = 1

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "explorer_projects"
  -- Stay permanently modifiable — it's wiped on close anyway.
  vim.bo[buf].modifiable = true
  vim.bo[buf].omnifunc = ""
  vim.bo[buf].completefunc = ""
  vim.b[buf].cmp_enabled = false
  vim.b[buf].blink_cmp_enabled = false
  vim.b[buf].completion_enabled = false
  vim.b[buf].completion = false

  -- Initial placeholder line
  api.nvim_buf_set_lines(buf, 0, -1, false, { ICON_PREFIX })

  -- ── Floating window (centred) ────────────────────────────────────────
  local ui = api.nvim_list_uis()[1]
  local width = math.min(72, ui.width - 8)
  local height = math.min(26, ui.height - 6)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 󰉋 Projects ",
    title_pos = "center",
  })
  P.win = win

  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhl = "Normal:ExplorerNormal,FloatBorder:ExplorerSearchBorderActive,FloatTitle:ExplorerDirectory"

  -- ── Autocmds ────────────────────────────────────────────────────────

  -- Prevent cursor from straying below row 0 while in insert mode
  api.nvim_create_autocmd("CursorMovedI", {
    buffer = buf,
    callback = function()
      if not (P.win and api.nvim_win_is_valid(P.win)) then
        return
      end
      if api.nvim_win_get_cursor(P.win)[1] ~= 1 then
        pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
      end
    end,
  })

  -- Live-filter: rebuild on every keystroke
  api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if not (P.win and api.nvim_win_is_valid(P.win)) then
        return
      end
      if api.nvim_win_get_cursor(P.win)[1] ~= 1 then
        return
      end

      local raw = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      local text
      if raw:sub(1, #ICON_PREFIX) == ICON_PREFIX then
        text = raw:sub(#ICON_PREFIX + 1)
      else
        -- Prefix was damaged — silently restore it
        text = ""
        api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
        pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
      end

      P.filter = text
      P.cursor = 1
      apply_filter()
      paint_items()
      paint_header()
    end,
  })

  -- Cleanup when the window is closed by any means
  api.nvim_create_autocmd("WinClosed", {
    buffer = buf,
    once = true,
    callback = function()
      P.win = nil
      P.buf = nil
    end,
  })

  -- ── Keymaps ─────────────────────────────────────────────────────────

  local bopts = { buffer = buf, silent = true, noremap = true }

  -- Navigation (insert + normal)
  vim.keymap.set({ "i", "n" }, "<C-j>", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<C-k>", function()
    move_cursor(-1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<Down>", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<Up>", function()
    move_cursor(-1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<C-d>", function()
    move_cursor(5)
  end, bopts)

  -- <C-u> in insert → wipe filter; in normal → scroll up 5
  vim.keymap.set("i", "<C-u>", function()
    P.filter = ""
    P.cursor = 1
    apply_filter()
    api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
    pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
    paint_items()
    paint_header()
  end, bopts)
  vim.keymap.set("n", "<C-u>", function()
    move_cursor(-5)
  end, bopts)

  -- Confirm
  vim.keymap.set({ "i", "n" }, "<CR>", open_selected, bopts)
  vim.keymap.set({ "i", "n" }, "P", toggle_pin_selected, bopts)
  vim.keymap.set({ "i", "n" }, "D", remove_selected, bopts)

  -- Close
  vim.keymap.set({ "i", "n" }, "<Esc>", M.close, bopts)
  vim.keymap.set("n", "q", M.close, bopts)

  -- <BS>: block deletion into the icon prefix zone
  vim.keymap.set("i", "<BS>", function()
    if not (P.win and api.nvim_win_is_valid(P.win)) then
      return "<BS>"
    end
    return api.nvim_win_get_cursor(P.win)[2] <= #ICON_PREFIX and "" or "<BS>"
  end, { buffer = buf, silent = true, noremap = true, expr = true })

  -- <Home> / <C-a>: jump to start of filter text (not col 0)
  local function to_filter_start()
    if P.win and api.nvim_win_is_valid(P.win) then
      pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
    end
  end
  vim.keymap.set("i", "<Home>", to_filter_start, bopts)
  vim.keymap.set("i", "<C-a>", to_filter_start, bopts)

  -- Block completion popups
  for _, k in ipairs({
    "<Tab>",
    "<S-Tab>",
    "<C-n>",
    "<C-p>",
    "<C-y>",
    "<C-e>",
    "<C-x><C-o>",
    "<C-x><C-n>",
    "<C-x><C-f>",
    "<C-x><C-l>",
  }) do
    vim.keymap.set("i", k, "<Nop>", bopts)
  end

  -- ── Load projects then enter insert ─────────────────────────────────
  collect_projects(vim.schedule_wrap(function(projects)
    if not (P.buf and api.nvim_buf_is_valid(buf)) then
      return
    end
    P.projects = projects
    apply_filter()
    paint_all()
    pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
    vim.cmd("startinsert!")
  end))
end

return M
