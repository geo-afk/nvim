-- =============================================================================
-- explorer.lua  v3
-- =============================================================================
-- Drop at  ~/.config/nvim/lua/explorer.lua  and call require("explorer").setup()
--
-- BUFFERLINE OFFSET — add to your bufferline.setup():
--   offsets = {{ filetype="explorer", text="Explorer", separator=true }}
--
-- Changes from v2:
--  • Current path shown in winbar (not as a buffer line) — l/h never land on it
--  • Serial DFS tree builder — expanded folders appear directly below their parent
--  • Git badges rendered as extmarks (virt_text) — git refreshes never move cursor
--  • Toggle always closes if explorer is visible — no double-press needed
--  • All close/WinClosed paths are pcall-safe — no more close errors
-- =============================================================================

local M = {}
local api = vim.api
local uv = vim.uv or vim.loop
local fn = vim.fn

-------------------------------------------------------------------------------
-- 1. CONFIG DEFAULTS
-------------------------------------------------------------------------------

M.defaults = {
  width = 34,
  side = 'left', -- "left" | "right"
  show_hidden = false,
  show_git = true,
  follow_file = true, -- move cursor to active file on BufEnter
  auto_close = false, -- close explorer when opening a file

  -- Icon provider: "auto" | "mini" | "devicons" | "builtin" | "none"
  --   auto  → tries MiniIcons → nvim-web-devicons → built-in glyph table
  icons = { style = 'auto' },

  -- Unicode box-drawing tree connectors
  tree = { last = '└ ', branch = '├ ', vert = '│ ', blank = '  ' },

  keymaps = {
    -- Global mappings (set to "" to disable)
    toggle = '<leader>e',
    reveal = '<leader>E',

    -- Buffer-local (only inside the explorer window)
    open = { '<CR>', 'l' },
    close_dir = 'h',
    go_up = '-',
    vsplit = 'v',
    split = 's',
    tab = 't',
    add = 'a', -- end with / to create a directory
    delete = 'd',
    rename = 'r',
    copy = 'c',
    toggle_hidden = '.',
    refresh = 'R',
    copy_path = 'y',
    quit = 'q',
    help = '?',
  },
}

-------------------------------------------------------------------------------
-- 2. BUILT-IN ICON TABLE  (Nerd Font v3, zero external deps)
-------------------------------------------------------------------------------

local _EXT = {
  lua = '󰢱',
  py = '󰌠',
  rb = '󰴭',
  js = '󰌞',
  ts = '󰛦',
  jsx = '󰌞',
  tsx = '󰛦',
  sh = '󰒓',
  bash = '󰒓',
  zsh = '󰒓',
  fish = '󰒓',
  ps1 = '󰒓',
  vim = '',
  nvim = '',
  json = '󰘦',
  jsonc = '󰘦',
  yaml = '󰘦',
  yml = '󰘦',
  toml = '󰘦',
  ini = '󰘦',
  cfg = '󰘦',
  env = '',
  html = '󰌝',
  htm = '󰌝',
  xml = '󰗀',
  svg = '󰜡',
  css = '󰌜',
  scss = '󰌜',
  less = '󰌜',
  md = '󰍔',
  mdx = '󰍔',
  rst = '󰗚',
  tex = '󰙩',
  txt = '󰈙',
  c = '󰙱',
  h = '󰙱',
  cpp = '󰙲',
  hpp = '󰙲',
  cs = '󰌛',
  rs = '󰈸',
  go = '󰟓',
  java = '󰬷',
  kt = '󰬱',
  swift = '󰛄',
  dart = '󰈜',
  sql = '󰆼',
  db = '󰆼',
  sqlite = '󰆼',
  csv = '󰈙',
  tsv = '󰈙',
  png = '󰈟',
  jpg = '󰈟',
  jpeg = '󰈟',
  gif = '󰈟',
  bmp = '󰈟',
  ico = '󰈟',
  webp = '󰈟',
  mp4 = '󰈫',
  mov = '󰈫',
  mkv = '󰈫',
  avi = '󰈫',
  mp3 = '󰈣',
  wav = '󰈣',
  flac = '󰈣',
  zip = '󰗄',
  tar = '󰗄',
  gz = '󰗄',
  bz2 = '󰗄',
  xz = '󰗄',
  rar = '󰗄',
  ['7z'] = '󰗄',
  pdf = '󰈦',
  lock = '󰌾',
  log = '󰱻',
  diff = '',
  patch = '',
  dockerfile = '󰡨',
  makefile = '󱁤',
  gitignore = '󰊢',
  gitattributes = '󰊢',
}
local _NAMES = {
  ['.gitignore'] = '󰊢',
  ['.gitattributes'] = '󰊢',
  ['.gitmodules'] = '󰊢',
  ['makefile'] = '󱁤',
  ['dockerfile'] = '󰡨',
  ['docker-compose.yml'] = '󰡨',
  ['readme.md'] = '󰍔',
  ['license'] = '󰿃',
  ['.env'] = '',
  ['.env.local'] = '',
  ['.env.example'] = '',
  ['package.json'] = '󰎙',
  ['package-lock.json'] = '󰎙',
  ['cargo.toml'] = '󰈸',
  ['cargo.lock'] = '󰈸',
  ['go.mod'] = '󰟓',
  ['go.sum'] = '󰟓',
}
local _DIR_OPEN = '󰝰 '
local _DIR_CLOSED = '󰉋 '
local _SYMLINK = '󰉒 '
local _FILE_DEF = '󰈙 '

-------------------------------------------------------------------------------
-- 3. STATE
-------------------------------------------------------------------------------

local S = {
  buf = nil, -- explorer buffer handle
  win = nil, -- explorer window handle
  root = nil, -- absolute root path (no trailing slash)
  open_dirs = {}, -- set<path> → true for expanded dirs
  items = {}, -- flat list; index == line number in buffer
  git = {}, -- path → status char
  ns = api.nvim_create_namespace 'explorer_tree',
  git_ns = api.nvim_create_namespace 'explorer_git',
  prev_win = nil, -- window to return focus to when opening files
  icon_fn = nil, -- resolved fn(path, is_dir) → "icon ", hl_group|nil
}

-- Guard against concurrent tree builds.  When a new build starts,
-- the old one is abandoned by incrementing this token.
local _build_token = 0

-------------------------------------------------------------------------------
-- 4. ICON RESOLUTION
-------------------------------------------------------------------------------

local function _icon_builtin(path, is_dir)
  if is_dir then
    return _DIR_CLOSED, 'Directory'
  end
  local ls = uv.fs_lstat(path)
  if ls and ls.type == 'link' then
    return _SYMLINK, 'Comment'
  end
  local name = fn.fnamemodify(path, ':t'):lower()
  local ext = name:match '%.([^.]+)$' or ''
  return (_NAMES[name] or _EXT[ext] or _FILE_DEF:gsub(' $', '')), nil
end

local function _icon_none(_, is_dir)
  return is_dir and '▶' or ' ', nil
end

local function _icon_mini(path, is_dir)
  -- MiniIcons.get returns (icon, hl, is_default)
  local ok, icon, hl
  if is_dir then
    ok, icon, hl = pcall(MiniIcons.get, 'directory', path) --luacheck:ignore
  else
    ok, icon, hl = pcall(MiniIcons.get, 'file', path) --luacheck:ignore
  end
  if ok and icon then
    return icon, hl
  end
  return _icon_builtin(path, is_dir)
end

local function _icon_devicons(path, is_dir)
  if is_dir then
    return _DIR_CLOSED:gsub(' $', ''), 'Directory'
  end
  local dv = package.loaded['nvim-web-devicons']
  if dv then
    local icon, hl = dv.get_icon(fn.fnamemodify(path, ':t'), fn.fnamemodify(path, ':e'), { default = true })
    if icon then
      return icon, hl
    end
  end
  return _icon_builtin(path, is_dir)
end

local function resolve_icon_fn()
  local style = (M.config or M.defaults).icons.style
  if style == 'none' then
    return _icon_none
  end
  if style == 'mini' then
    return _icon_mini
  end
  if style == 'devicons' then
    return _icon_devicons
  end
  -- "auto" or "builtin"
  if _G.MiniIcons then
    return _icon_mini
  end
  if package.loaded['nvim-web-devicons'] then
    return _icon_devicons
  end
  return _icon_builtin
end

-------------------------------------------------------------------------------
-- 5. PATH HELPERS
-------------------------------------------------------------------------------

local function norm(p)
  return (p:gsub('//+', '/'):gsub('/$', ''))
end
local function join(a, b)
  return norm(a .. '/' .. b)
end
local function parent(p)
  return p:match '^(.*)/[^/]+$' or '/'
end

-------------------------------------------------------------------------------
-- 6. SERIAL DFS TREE BUILDER
--
-- Uses uv.fs_scandir (one async syscall per directory), then processes
-- entries synchronously within that directory before recursing into any
-- open sub-directories.  This guarantees correct DFS order:
--
--    ├  src/          ← open dir
--    │  ├  foo.lua    ← appears RIGHT below src/, not at the bottom
--    │  └  bar.lua
--    └  tests/
--
-- Each open directory yields via vim.schedule before recursing, so the
-- event loop stays responsive even for large trees.
-------------------------------------------------------------------------------

local function _scandir_sync(path, show_hidden)
  -- uv.fs_scandir() without callback = synchronous (fast per-dir syscall)
  local handle, err = uv.fs_scandir(path)
  if not handle then
    return {}
  end
  local entries = {}
  while true do
    local name, t = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if show_hidden or name:sub(1, 1) ~= '.' then
      local abs = join(path, name)
      if t == 'link' then
        local s = uv.fs_stat(abs)
        t = s and s.type or 'link'
      end
      entries[#entries + 1] = { name = name, type = t, path = abs }
    end
  end
  table.sort(entries, function(a, b)
    local ad, bd = a.type == 'directory' and 0 or 1, b.type == 'directory' and 0 or 1
    if ad ~= bd then
      return ad < bd
    end
    return a.name:lower() < b.name:lower()
  end)
  return entries
end

-- build_tree(root, open_dirs, show_hidden, token, done)
--   token: if _build_token changes mid-build, this build is abandoned.
--   done(items): called once with the complete flat DFS list.
local function build_tree(root, open_dirs, show_hidden, token, done)
  local result = {}

  local function walk(path, depth, parents_last, on_done)
    -- Yield to the event loop between directory reads
    vim.schedule(function()
      if _build_token ~= token then
        return
      end -- stale, abandon

      local entries = _scandir_sync(path, show_hidden)
      local n = #entries

      local function process(i)
        if _build_token ~= token then
          return
        end
        if i > n then
          on_done()
          return
        end

        local e = entries[i]
        local is_last = (i == n)
        local is_open = open_dirs[e.path] == true

        result[#result + 1] = {
          path = e.path,
          name = e.name,
          depth = depth,
          is_dir = (e.type == 'directory'),
          is_open = is_open,
          is_last = is_last,
          parents_last = parents_last,
        }

        if e.type == 'directory' and is_open then
          local pl = vim.list_extend({}, parents_last)
          pl[#pl + 1] = is_last
          -- Recurse, then continue with next sibling
          walk(e.path, depth + 1, pl, function()
            process(i + 1)
          end)
        else
          process(i + 1)
        end
      end

      process(1)
    end)
  end

  walk(root, 0, {}, function()
    if _build_token == token then
      done(result)
    end
  end)
end

-------------------------------------------------------------------------------
-- 7. WINBAR (path display — separate from buffer content)
--
-- The root path is shown in the per-window winbar, not as a buffer line.
-- This means S.items[1] is always a real tree entry, and l/h/CR never
-- accidentally land on a "header" that would navigate to $HOME.
-------------------------------------------------------------------------------

local function update_winbar()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  local path = fn.fnamemodify(S.root, ':~')
  -- Use pcall: winbar was added in nvim 0.8; silently skip on older builds
  pcall(function()
    vim.wo[S.win].winbar = '  󰝰  ' .. path .. ' '
  end)
end

-------------------------------------------------------------------------------
-- 8. GIT STATUS  (async, extmark-based — never rebuilds the tree)
--
-- Git badges are rendered as virtual text (virt_text_pos="eol") in their
-- own namespace (S.git_ns).  Refreshing git status only replaces the
-- extmarks; it never touches buffer lines or the cursor position.
-------------------------------------------------------------------------------

local GIT_HL = {
  A = 'DiffAdd',
  M = 'DiffChange',
  D = 'DiffDelete',
  R = 'DiffChange',
  U = 'DiffChange',
  ['?'] = 'Comment',
}

-- Re-applies git extmarks using the current S.git and S.items.
-- Safe to call at any time — no line writes, no cursor movement.
local function apply_git_marks()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.git_ns, 0, -1)
  for i, item in ipairs(S.items) do
    local ch = S.git[item.path]
    if ch then
      pcall(api.nvim_buf_set_extmark, buf, S.git_ns, i - 1, 0, {
        virt_text = { { '  ' .. ch, GIT_HL[ch] or 'Comment' } },
        virt_text_pos = 'eol',
        priority = 10,
      })
    end
  end
end

local function update_git()
  if not (M.config or M.defaults).show_git then
    return
  end
  vim.system(
    { 'git', '-C', S.root, 'status', '--porcelain', '-u' },
    { text = true },
    vim.schedule_wrap(function(out)
      if (out.code or 1) ~= 0 then
        return
      end
      local git = {}
      for line in (out.stdout or ''):gmatch '[^\n]+' do
        if #line >= 4 then
          local xy = line:sub(1, 2)
          local path = line:sub(4)
          path = path:match '^.+ %-> (.+)$' or path
          path = path:gsub('^"', ''):gsub('"$', '')
          local ch = xy:gsub(' ', ''):sub(1, 1)
          if ch ~= '' then
            git[norm(S.root .. '/' .. path)] = ch
          end
        end
      end
      S.git = git
      apply_git_marks() -- extmarks only — no line rebuild, no cursor jump
    end)
  )
end

-------------------------------------------------------------------------------
-- 9. RENDERING
--
-- render()     – invalidate + schedule a full async tree rebuild + repaint
-- _do_render() – synchronous paint from current S.items (called by render's
--                build_tree callback and by reveal())
--
-- Neither function touches cursor position when called for a git-only update
-- because git updates no longer go through this path (see §8).
-------------------------------------------------------------------------------

local _render_tok = nil -- debounce: only the latest scheduled render runs

function M.render()
  local tok = {} -- unique object used as identity token
  _render_tok = tok
  _build_token = _build_token + 1
  local my_token = _build_token

  vim.schedule(function()
    if _render_tok ~= tok then
      return
    end
    _render_tok = nil
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
      return
    end
    local cfg = M.config or M.defaults

    build_tree(S.root, S.open_dirs, cfg.show_hidden, my_token, function(items)
      S.items = items
      M._do_render()
      apply_git_marks()
    end)
  end)
end

function M._do_render()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  local cfg = M.config or M.defaults
  local tc = cfg.tree
  local ifn = S.icon_fn or resolve_icon_fn()

  -- Save cursor row so we can restore it after rewriting lines.
  local saved_row = 1
  if S.win and api.nvim_win_is_valid(S.win) then
    saved_row = api.nvim_win_get_cursor(S.win)[1]
  end

  local lines = {}
  local hls = {}

  for _, item in ipairs(S.items) do
    -- Tree connectors
    local prefix = ''
    for _, last in ipairs(item.parents_last) do
      prefix = prefix .. (last and tc.blank or tc.vert)
    end
    prefix = prefix .. (item.is_last and tc.last or tc.branch)

    -- Icon
    local icon_raw, icon_hl
    if item.is_dir then
      icon_raw = item.is_open and _DIR_OPEN or _DIR_CLOSED
      icon_hl = 'Directory'
    else
      icon_raw, icon_hl = ifn(item.path, false)
    end
    local icon = icon_raw .. ' ' -- trailing space between icon and name

    local line = prefix .. icon .. item.name -- NO git text in buffer line
    lines[#lines + 1] = line

    local row = #lines - 1 -- 0-indexed
    local c1 = #prefix
    local c2 = c1 + #icon
    local c3 = c2 + #item.name

    hls[#hls + 1] = { row, 0, c1, 'NonText' }
    if icon_hl then
      hls[#hls + 1] = { row, c1, c2, icon_hl }
    end
    hls[#hls + 1] = { row, c2, c3, item.is_dir and 'Directory' or 'Normal' }
  end

  -- Write buffer (briefly make it modifiable)
  api.nvim_buf_set_option(buf, 'modifiable', true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(api.nvim_buf_add_highlight, buf, S.ns, h[4], h[1], h[2], h[3])
  end
  api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Restore cursor, clamped to valid range
  if S.win and api.nvim_win_is_valid(S.win) then
    local max = math.max(1, #lines)
    pcall(api.nvim_win_set_cursor, S.win, { math.min(saved_row, max), 0 })
  end
end

-------------------------------------------------------------------------------
-- 10. CURSOR → ITEM
-------------------------------------------------------------------------------

function M.current_item()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil
  end
  local row = api.nvim_win_get_cursor(S.win)[1]
  return S.items[row]
end

-------------------------------------------------------------------------------
-- 11. TARGET WINDOW  (where files are opened)
-------------------------------------------------------------------------------

local function target_win()
  local function usable(w)
    if w == S.win then
      return false
    end
    local bt = vim.bo[api.nvim_win_get_buf(w)].buftype
    return bt == '' or bt == 'nowrite'
  end
  if S.prev_win and api.nvim_win_is_valid(S.prev_win) and usable(S.prev_win) then
    return S.prev_win
  end
  for _, w in ipairs(api.nvim_list_wins()) do
    if usable(w) then
      return w
    end
  end
end

local function open_in(path, cmd)
  local tw = target_win()
  if tw then
    api.nvim_set_current_win(tw)
  else
    local opp = (M.config or M.defaults).side == 'right' and 'aboveleft' or 'belowright'
    vim.cmd(opp .. ' vsplit')
  end
  vim.cmd(cmd .. ' ' .. fn.fnameescape(path))
end

-------------------------------------------------------------------------------
-- 12. TREE ACTIONS
-------------------------------------------------------------------------------

function M.open_or_toggle()
  local item = M.current_item()
  if not item then
    return
  end
  if item.is_dir then
    -- Toggle expansion
    S.open_dirs[item.path] = not S.open_dirs[item.path] or nil
    M.render()
  else
    open_in(item.path, 'edit')
    if (M.config or M.defaults).auto_close then
      M.close()
    end
  end
end

function M.close_dir()
  local item = M.current_item()
  if not item then
    return
  end
  -- If on an open dir → collapse it
  if item.is_dir and S.open_dirs[item.path] then
    S.open_dirs[item.path] = nil
    M.render()
    return
  end
  -- Otherwise collapse the parent dir and jump to it
  local par = parent(item.path)
  if par == S.root then
    return
  end
  S.open_dirs[par] = nil
  M.render()
  vim.schedule(function()
    for i, it in ipairs(S.items) do
      if it.path == par then
        pcall(api.nvim_win_set_cursor, S.win, { i, 0 })
        break
      end
    end
  end)
end

function M.go_up()
  local up = parent(S.root)
  if up == S.root then
    return
  end -- already at filesystem root
  local old = S.root
  S.root = up
  S.open_dirs[old] = true -- keep the old root expanded
  update_winbar()
  M.render()
  update_git()
  -- Move cursor to the old-root entry after rebuild
  vim.schedule(function()
    for i, it in ipairs(S.items) do
      if it.path == old then
        pcall(api.nvim_win_set_cursor, S.win, { i, 0 })
        break
      end
    end
  end)
end

function M.vsplit()
  local i = M.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'vsplit')
  end
end
function M.split()
  local i = M.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'split')
  end
end
function M.tab_open()
  local i = M.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'tabedit')
  end
end

function M.add()
  local item = M.current_item()
  local dir = item and (item.is_dir and item.path or parent(item.path)) or S.root
  vim.ui.input({ prompt = 'New (end with / for dir): ', default = dir .. '/' }, function(name)
    if not name or name == '' then
      return
    end
    name = norm(name)
    if vim.endswith(name, '/') then
      fn.mkdir(name, 'p')
    else
      fn.mkdir(parent(name), 'p')
      local f = io.open(name, 'w')
      if f then
        f:close()
      end
    end
    M.refresh()
  end)
end

function M.delete()
  local item = M.current_item()
  if not item then
    return
  end
  local label = item.is_dir and (item.name .. '/') or item.name
  vim.ui.input({ prompt = 'Delete ' .. label .. '? (y/N): ' }, function(ans)
    if ans and ans:lower() == 'y' then
      fn.delete(item.path, item.is_dir and 'rf' or '')
      M.refresh()
    end
  end)
end

function M.rename()
  local item = M.current_item()
  if not item then
    return
  end
  vim.ui.input({ prompt = 'Rename to: ', default = item.path }, function(dest)
    if not dest or dest == '' or dest == item.path then
      return
    end
    dest = norm(dest)
    fn.mkdir(parent(dest), 'p')
    fn.rename(item.path, dest)
    -- Notify any LSP clients that support workspace/didRenameFiles (no dep needed)
    for _, client in ipairs(vim.lsp.get_clients()) do
      local caps = ((client.server_capabilities.workspace or {}).fileOperations or {})
      if caps.didRename then
        client.notify('workspace/didRenameFiles', {
          files = { { oldUri = vim.uri_from_fname(item.path), newUri = vim.uri_from_fname(dest) } },
        })
      end
    end
    M.refresh()
  end)
end

function M.copy()
  local item = M.current_item()
  if not item then
    return
  end
  vim.ui.input({ prompt = 'Copy to: ', default = item.path }, function(dest)
    if not dest or dest == '' or dest == item.path then
      return
    end
    dest = norm(dest)
    fn.mkdir(parent(dest), 'p')
    local cmd = item.is_dir and { 'cp', '-r', item.path, dest } or { 'cp', item.path, dest }
    vim.system(cmd, {}, function(out)
      vim.schedule(function()
        if out.code ~= 0 then
          vim.notify('[explorer] copy failed: ' .. (out.stderr or ''), vim.log.levels.ERROR)
        else
          M.refresh()
        end
      end)
    end)
  end)
end

function M.toggle_hidden()
  local cfg = M.config or M.defaults
  cfg.show_hidden = not cfg.show_hidden
  M.render()
end

function M.copy_path()
  local item = M.current_item()
  if not item then
    return
  end
  local p = item.path
  vim.ui.select({
    { label = 'Absolute', val = p },
    { label = 'Relative to CWD', val = fn.fnamemodify(p, ':.') },
    { label = 'Home-relative', val = fn.fnamemodify(p, ':~') },
    { label = 'Filename', val = fn.fnamemodify(p, ':t') },
    { label = 'Stem (no ext)', val = fn.fnamemodify(p, ':t:r') },
  }, {
    prompt = 'Copy path:',
    format_item = function(o)
      return ('%-20s  %s'):format(o.label, o.val)
    end,
  }, function(choice)
    if not choice then
      return
    end
    fn.setreg('+', choice.val)
    fn.setreg('"', choice.val)
    vim.notify('[explorer] ' .. choice.val, vim.log.levels.INFO)
  end)
end

function M.show_help()
  local km = (M.config or M.defaults).keymaps
  local function k(key)
    return type(key) == 'table' and table.concat(key, '/') or (key or '')
  end
  local rows = {
    { k(km.open), 'open / expand-collapse' },
    { k(km.close_dir), 'collapse / jump to parent' },
    { k(km.go_up), 'go up one level' },
    { k(km.vsplit), 'open in vertical split' },
    { k(km.split), 'open in horizontal split' },
    { k(km.tab), 'open in new tab' },
    { k(km.add), 'add file (end name with / for dir)' },
    { k(km.delete), 'delete (with confirm)' },
    { k(km.rename), 'rename / move' },
    { k(km.copy), 'copy to path' },
    { k(km.toggle_hidden), 'toggle hidden files' },
    { k(km.refresh), 'refresh tree + git' },
    { k(km.copy_path), 'copy path to clipboard' },
    { k(km.quit), 'close explorer' },
    { k(km.help), 'this help' },
  }
  local lines = { '  Explorer keymaps', '  ' .. string.rep('─', 44) }
  for _, r in ipairs(rows) do
    lines[#lines + 1] = ('  %-14s  %s'):format(r[1], r[2])
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = '  Press q, ?, CR or <Esc> to close'

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local w, h = 52, #lines
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    title = ' Help ',
    title_pos = 'center',
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
  })
  local cls = function()
    pcall(api.nvim_win_close, win, true)
  end
  for _, key in ipairs { 'q', '?', '<CR>', '<Esc>' } do
    vim.keymap.set('n', key, cls, { buffer = buf, silent = true })
  end
  api.nvim_create_autocmd('BufLeave', { buffer = buf, once = true, callback = cls })
end

function M.refresh()
  update_git()
  M.render()
end

-------------------------------------------------------------------------------
-- 13. REVEAL / FOLLOW
--
-- Expands all ancestor directories of `path` inside the current root,
-- rebuilds the tree, then moves the cursor to the target entry.
--
-- If the file is already the cursor's current line, this is a no-op so
-- BufEnter follow doesn't cause constant jumping on FS-watcher events.
-------------------------------------------------------------------------------

function M.reveal(path)
  if not path or path == '' then
    return
  end
  path = norm(fn.fnamemodify(path, ':p'))
  if not vim.startswith(path, S.root) then
    return
  end

  -- Short-circuit: already on this file
  local cur = M.current_item()
  if cur and cur.path == path then
    return
  end

  -- Expand ancestor directories
  local rel = path:sub(#S.root + 2)
  local parts = vim.split(rel, '/', { plain = true })
  local acc = S.root
  for i = 1, #parts - 1 do
    acc = join(acc, parts[i])
    S.open_dirs[acc] = true
  end

  -- Rebuild, repaint, then position cursor
  _build_token = _build_token + 1
  local tok = _build_token
  local cfg = M.config or M.defaults
  build_tree(S.root, S.open_dirs, cfg.show_hidden, tok, function(items)
    S.items = items
    M._do_render()
    apply_git_marks()
    vim.schedule(function()
      for i, it in ipairs(S.items) do
        if it.path == path then
          pcall(api.nvim_win_set_cursor, S.win, { i, 0 })
          return
        end
      end
    end)
  end)
end

-------------------------------------------------------------------------------
-- 14. FILE WATCHER  (debounced, cleans up safely)
-------------------------------------------------------------------------------

local _watcher, _debounce

local function watch_start()
  -- Clean up any existing watcher first
  if _watcher then
    pcall(function()
      _watcher:stop()
    end)
    pcall(function()
      _watcher:close()
    end)
    _watcher = nil
  end
  local w, err = uv.new_fs_event()
  if not w then
    return
  end
  local ok = w:start(S.root, { recursive = true }, function(fs_err)
    if fs_err then
      return
    end
    if _debounce then
      _debounce:stop()
    end
    _debounce = vim.defer_fn(function()
      _debounce = nil
      -- Only rebuild the tree; git is refreshed separately to avoid cursor jump
      M.render()
      update_git()
    end, 250)
  end)
  if ok == 0 or ok == nil then
    _watcher = w
  else
    pcall(function()
      w:close()
    end)
  end
end

local function watch_stop()
  if _debounce then
    pcall(function()
      _debounce:stop()
    end)
    _debounce = nil
  end
  if _watcher then
    pcall(function()
      _watcher:stop()
    end)
    pcall(function()
      _watcher:close()
    end)
    _watcher = nil
  end
end

-------------------------------------------------------------------------------
-- 15. HIGHLIGHT GROUPS  (derived from colorscheme at runtime)
-------------------------------------------------------------------------------

local function ensure_hl()
  local ok, existing = pcall(api.nvim_get_hl, 0, { name = 'ExplorerNormal' })
  if ok and existing and next(existing) then
    return
  end -- already set

  local float = api.nvim_get_hl(0, { name = 'NormalFloat' })
  local normal = api.nvim_get_hl(0, { name = 'Normal' })
  local cursor = api.nvim_get_hl(0, { name = 'CursorLine' })

  api.nvim_set_hl(0, 'ExplorerNormal', { bg = float.bg or normal.bg, fg = normal.fg })
  api.nvim_set_hl(0, 'ExplorerCursorLine', { bg = cursor.bg or 'NONE', bold = true })
  api.nvim_set_hl(0, 'ExplorerWinBar', { bg = float.bg or normal.bg, bold = true })
end

-------------------------------------------------------------------------------
-- 16. BUFFER / WINDOW CREATION
-------------------------------------------------------------------------------

local function make_buf()
  local buf = api.nvim_create_buf(false, true)
  -- Give it a stable name; make it hidden (never auto-closed by Neovim)
  pcall(api.nvim_buf_set_name, buf, 'explorer://')
  local bo = vim.bo[buf]
  bo.buftype = 'nofile'
  bo.bufhidden = 'hide'
  bo.buflisted = false
  bo.filetype = 'explorer' -- used by bufferline offsets
  bo.modifiable = false
  bo.swapfile = false
  return buf
end

local function make_win(buf, cfg)
  ensure_hl()
  local side = cfg.side == 'right' and 'botright' or 'topleft'
  vim.cmd(side .. ' ' .. cfg.width .. 'vsplit')
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)

  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  wo.winfixwidth = true
  wo.wrap = false
  wo.spell = false
  wo.list = false
  wo.cursorline = true
  wo.fillchars = 'eob: '
  wo.winhl = 'Normal:ExplorerNormal,CursorLine:ExplorerCursorLine,WinBar:ExplorerWinBar,WinBarNC:ExplorerWinBar'
  pcall(function()
    wo.statuscolumn = ''
  end)
  pcall(function()
    wo.foldcolumn = '0'
  end)

  return win
end

local function setup_buf_keymaps(buf)
  local km = (M.config or M.defaults).keymaps
  local opts = { noremap = true, silent = true, nowait = true, buffer = buf }
  local function map(keys, action)
    if type(keys) == 'string' then
      keys = { keys }
    end
    for _, key in ipairs(keys) do
      if key and key ~= '' then
        vim.keymap.set('n', key, action, opts)
      end
    end
  end
  map(km.open, M.open_or_toggle)
  map(km.close_dir, M.close_dir)
  map(km.go_up, M.go_up)
  map(km.vsplit, M.vsplit)
  map(km.split, M.split)
  map(km.tab, M.tab_open)
  map(km.add, M.add)
  map(km.delete, M.delete)
  map(km.rename, M.rename)
  map(km.copy, M.copy)
  map(km.toggle_hidden, M.toggle_hidden)
  map(km.refresh, M.refresh)
  map(km.copy_path, M.copy_path)
  map(km.quit, M.close)
  map(km.help, M.show_help)
end

-------------------------------------------------------------------------------
-- 17. OPEN / CLOSE / TOGGLE
-------------------------------------------------------------------------------

function M.open(opts)
  opts = opts or {}
  local cfg = M.config or M.defaults

  local cw = api.nvim_get_current_win()
  if cw ~= S.win then
    S.prev_win = cw
  end

  S.root = norm(fn.fnamemodify(opts.root or fn.getcwd(), ':p'))

  -- Create buffer once
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    S.buf = make_buf()
    setup_buf_keymaps(S.buf)
  end

  -- Re-resolve icon provider (may have been loaded after setup)
  S.icon_fn = resolve_icon_fn()

  -- Create window if not visible
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    S.win = make_win(S.buf, cfg)
  end

  update_winbar()
  M.render()
  update_git()
  watch_start()

  if cfg.follow_file then
    -- Reveal the file that was active in the previous window
    local src_buf = (cw == S.win) and 0 or api.nvim_win_get_buf(cw)
    local path = api.nvim_buf_get_name(src_buf)
    if path and path ~= '' then
      M.reveal(path)
    end
  end

  api.nvim_set_current_win(S.win)
end

-- close() is called from keymaps, WinClosed, and toggle().
-- It must be idempotent and pcall-safe.
function M.close()
  watch_stop()
  if S.win and api.nvim_win_is_valid(S.win) then
    -- Temporarily mark S.win nil BEFORE closing to prevent WinClosed
    -- re-entrance from doing redundant work.
    local win = S.win
    S.win = nil
    pcall(api.nvim_win_close, win, true)
  else
    S.win = nil
  end
end

-- toggle() always toggles VISIBILITY — one press closes, one press opens.
-- When the explorer is already open but unfocused (user is in an editor
-- window), pressing the mapping closes it instead of requiring a second
-- press.  Use <leader>E (reveal) if you want to focus without closing.
function M.toggle(opts)
  if S.win and api.nvim_win_is_valid(S.win) then
    M.close()
  else
    M.open(opts)
  end
end

-------------------------------------------------------------------------------
-- 18. SETUP
-------------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
  local cfg = M.config

  -- ── Commands ──────────────────────────────────────────────────────────────
  api.nvim_create_user_command('Explorer', function(a)
    M.toggle { root = a.args ~= '' and a.args or nil }
  end, { nargs = '?', complete = 'dir', desc = 'Toggle file explorer' })

  api.nvim_create_user_command('ExplorerReveal', function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      M.open()
    end
    M.reveal(api.nvim_buf_get_name(0))
  end, { desc = 'Reveal current file in explorer' })

  -- ── Global keymaps ────────────────────────────────────────────────────────
  local km = cfg.keymaps
  if km.toggle and km.toggle ~= '' then
    vim.keymap.set('n', km.toggle, M.toggle, { silent = true, desc = 'Toggle explorer' })
  end
  if km.reveal and km.reveal ~= '' then
    vim.keymap.set('n', km.reveal, function()
      if not (S.win and api.nvim_win_is_valid(S.win)) then
        M.open()
      end
      M.reveal(api.nvim_buf_get_name(0))
      if S.win and api.nvim_win_is_valid(S.win) then
        api.nvim_set_current_win(S.win)
      end
    end, { silent = true, desc = 'Reveal file in explorer' })
  end

  -- ── Re-derive highlights when colorscheme changes ─────────────────────────
  api.nvim_create_autocmd('ColorScheme', {
    desc = 'explorer: refresh highlight groups',
    callback = function()
      pcall(api.nvim_set_hl, 0, 'ExplorerNormal', {})
      pcall(api.nvim_set_hl, 0, 'ExplorerCursorLine', {})
      pcall(api.nvim_set_hl, 0, 'ExplorerWinBar', {})
      ensure_hl()
      S.icon_fn = resolve_icon_fn()
    end,
  })

  -- ── BufEnter: reveal active file ──────────────────────────────────────────
  if cfg.follow_file then
    api.nvim_create_autocmd('BufEnter', {
      desc = 'explorer: follow active buffer',
      callback = function()
        if not (S.win and api.nvim_win_is_valid(S.win)) then
          return
        end
        if api.nvim_get_current_win() == S.win then
          return
        end
        if vim.bo.buftype ~= '' then
          return
        end
        local path = api.nvim_buf_get_name(0)
        if path ~= '' then
          M.reveal(path)
        end
      end,
    })
  end

  -- ── WinClosed: clean up state, quit if explorer is last window ────────────
  -- NOTE: We nil S.win at the START of M.close() to prevent re-entrance here.
  api.nvim_create_autocmd('WinClosed', {
    desc = 'explorer: cleanup on window close',
    callback = function(ev)
      local closed = tonumber(ev.match)
      -- If the explorer window was closed externally (not via M.close),
      -- clean up our state.
      if closed == S.win then
        S.win = nil
        watch_stop()
      end

      -- If only one non-float window remains and it is the explorer, quit.
      vim.schedule(function()
        local normal_wins = vim.tbl_filter(function(w)
          if not api.nvim_win_is_valid(w) then
            return false
          end
          return api.nvim_win_get_config(w).relative == ''
        end, api.nvim_list_wins())

        if #normal_wins == 1 and S.win and api.nvim_win_is_valid(S.win) and normal_wins[1] == S.win then
          vim.cmd 'quit'
        end
      end)
    end,
  })

  -- ── Keep explorer buffer unlisted ─────────────────────────────────────────
  api.nvim_create_autocmd('FileType', {
    pattern = 'explorer',
    desc = 'explorer: enforce buffer options',
    callback = function(ev)
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return M
