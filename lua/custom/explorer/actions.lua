-- explorer/actions.lua
-- All user-facing actions. Each function is self-contained and safe to
-- call from keymaps or external scripts.

local S = require 'custom.explorer.state'
local cfg = require 'custom.explorer.config'
local tree = require 'custom.explorer.tree'
local render = require 'custom.explorer.render'
local git = require 'custom.explorer.git'
local marks = require 'custom.explorer.marks'
local search = require 'custom.explorer.search'

local api = vim.api
local fn = vim.fn

local A = {}

-- ── Cursor helpers ────────────────────────────────────────────────────────

function A.current_item()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil
  end
  local row = api.nvim_win_get_cursor(S.win)[1] -- 1-based
  -- Line 1 = search area, Line 2 = padding; items start at line 3 → index row-2
  if row < 3 then
    return nil
  end
  return S.items[row - 2]
end

-- Find and jump cursor to item with the given path
function A.jump_to(path)
  for i, it in ipairs(S.items) do
    if it.path == path then
      -- +2: search=line1, padding=line2, item[1]=line3, …
      pcall(api.nvim_win_set_cursor, S.win, { i + 2, 0 })
      return true
    end
  end
  return false
end

-- ── Target window for file opening ───────────────────────────────────────

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
    local side = cfg.get().side == 'right' and 'aboveleft' or 'belowright'
    vim.cmd(side .. ' vsplit')
  end
  vim.cmd(cmd .. ' ' .. fn.fnameescape(path))
end

-- ── Tree navigation ───────────────────────────────────────────────────────

function A.open_or_toggle()
  local item = A.current_item()
  if not item then
    return
  end
  if item.is_dir then
    S.open_dirs[item.path] = not S.open_dirs[item.path] or nil
    render.render()
  else
    open_in(item.path, 'edit')
    if cfg.get().auto_close then
      require('custom.explorer').close()
    end
  end
end

function A.close_dir()
  local item = A.current_item()
  if not item then
    return
  end
  if item.is_dir and S.open_dirs[item.path] then
    S.open_dirs[item.path] = nil
    render.render()
    return
  end
  local par = tree.parent(item.path)
  if par == S.root then
    return
  end
  S.open_dirs[par] = nil
  render.render()
  vim.schedule(function()
    A.jump_to(par)
  end)
end

function A.go_up()
  local up = tree.parent(S.root)
  if up == S.root then
    return
  end
  local old = S.root
  S.root = up
  S.open_dirs[old] = true -- keep old root expanded
  render.render()
  git.fetch()
  vim.schedule(function()
    A.jump_to(old)
  end)
end

function A.collapse_all()
  S.open_dirs = {}
  render.render()
end

-- Expand all dirs to depth `max_depth` (default 1 = top-level only)
function A.expand_all(max_depth)
  max_depth = max_depth or 1
  local function expand(path, depth)
    if depth > max_depth then
      return
    end
    -- Scan synchronously (one level at a time — safe for small trees)
    local uv = vim.uv or vim.loop
    local handle = uv.fs_scandir(path)
    if not handle then
      return
    end
    while true do
      local name, t = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if t == 'directory' then
        local abs = tree.join(path, name)
        S.open_dirs[abs] = true
        expand(abs, depth + 1)
      end
    end
  end
  S.open_dirs = {}
  expand(S.root, 1)
  render.render()
end

function A.vsplit()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'vsplit')
  end
end
function A.split()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'split')
  end
end
function A.tab_open()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, 'tabedit')
  end
end

-- ── File operations ───────────────────────────────────────────────────────

function A.add()
  local item = A.current_item()
  local dir = item and (item.is_dir and item.path or tree.parent(item.path)) or S.root
  vim.ui.input({ prompt = 'New (end with / for dir): ', default = dir .. '/' }, function(name)
    if not name or name == '' then
      return
    end
    name = tree.norm(name)
    if vim.endswith(name, '/') then
      fn.mkdir(name, 'p')
    else
      fn.mkdir(tree.parent(name), 'p')
      local f = io.open(name, 'w')
      if f then
        f:close()
      end
    end
    A.refresh()
  end)
end

-- delete() operates on marks if any, otherwise current item
function A.delete()
  local item = A.current_item()
  local paths = marks.selection(item)
  if #paths == 0 then
    return
  end
  local mc = marks.count()
  local prompt = mc > 0 and ('Delete ' .. mc .. ' marked files? (y/N): ') or ('Delete ' .. fn.fnamemodify(paths[1], ':t') .. '? (y/N): ')
  vim.ui.input({ prompt = prompt }, function(ans)
    if not (ans and ans:lower() == 'y') then
      return
    end
    for _, p in ipairs(paths) do
      local stat = (vim.uv or vim.loop).fs_stat(p)
      if stat then
        fn.delete(p, stat.type == 'directory' and 'rf' or '')
      end
    end
    marks.clear()
    A.refresh()
  end)
end

function A.rename()
  local item = A.current_item()
  if not item then
    return
  end
  vim.ui.input({ prompt = 'Rename to: ', default = item.path }, function(dest)
    if not dest or dest == '' or dest == item.path then
      return
    end
    dest = tree.norm(dest)
    fn.mkdir(tree.parent(dest), 'p')
    fn.rename(item.path, dest)
    -- Notify LSP clients (zero-dep)
    for _, client in ipairs(vim.lsp.get_clients()) do
      local caps = ((client.server_capabilities.workspace or {}).fileOperations or {})
      if caps.didRename then
        client.notify('workspace/didRenameFiles', {
          files = { { oldUri = vim.uri_from_fname(item.path), newUri = vim.uri_from_fname(dest) } },
        })
      end
    end
    A.refresh()
  end)
end

-- copy() operates on marks if any, otherwise current item
function A.copy()
  local item = A.current_item()
  local paths = marks.selection(item)
  if #paths == 0 then
    return
  end
  if #paths == 1 then
    vim.ui.input({ prompt = 'Copy to: ', default = paths[1] }, function(dest)
      if not dest or dest == '' or dest == paths[1] then
        return
      end
      dest = tree.norm(dest)
      fn.mkdir(tree.parent(dest), 'p')
      local is_dir = (vim.uv or vim.loop).fs_stat(paths[1])
      local cmd = (is_dir and is_dir.type == 'directory') and { 'cp', '-r', paths[1], dest } or { 'cp', paths[1], dest }
      vim.system(cmd, {}, function(out)
        vim.schedule(function()
          if out.code ~= 0 then
            vim.notify('[explorer] copy failed: ' .. (out.stderr or ''), vim.log.levels.ERROR)
          else
            A.refresh()
          end
        end)
      end)
    end)
  else
    -- Multi-copy: ask for target directory
    vim.ui.input({ prompt = 'Copy ' .. #paths .. ' files to dir: ' }, function(dest)
      if not dest or dest == '' then
        return
      end
      dest = tree.norm(dest)
      fn.mkdir(dest, 'p')
      local cmds = {}
      for _, p in ipairs(paths) do
        cmds[#cmds + 1] = { 'cp', '-r', p, dest }
      end
      local function run_next(i)
        if i > #cmds then
          marks.clear()
          A.refresh()
          return
        end
        vim.system(cmds[i], {}, function()
          vim.schedule(function()
            run_next(i + 1)
          end)
        end)
      end
      run_next(1)
    end)
  end
end

-- ── Mark / multi-select ───────────────────────────────────────────────────

function A.toggle_mark()
  local item = A.current_item()
  if not item then
    return
  end
  marks.toggle(item)
  -- Move cursor down automatically (ergonomic for batch marking)
  -- Advance cursor down one item (ergonomic for batch marking)
  local row = api.nvim_win_get_cursor(S.win)[1]
  local max_row = #S.items + 2 -- items start at line 3, so last item = #items + 2
  pcall(api.nvim_win_set_cursor, S.win, { math.min(row + 1, max_row), 0 })
end

function A.clear_filter()
  require('custom.explorer.search').clear()
end

-- ── Git actions ───────────────────────────────────────────────────────────

local function git_op(item, args_fn, done_msg)
  local paths = marks.selection(item)
  if #paths == 0 then
    return
  end
  vim.system(vim.list_extend({ 'git', '-C', S.root }, args_fn(paths)), { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify('[explorer] git error:\n' .. (out.stderr or ''), vim.log.levels.ERROR)
      else
        if done_msg then
          vim.notify('[explorer] ' .. done_msg, vim.log.levels.INFO)
        end
        marks.clear()
        git.fetch() -- re-fetch status; apply() will repaint extmarks
      end
    end)
  end)
end

function A.git_stage()
  local item = A.current_item()
  git_op(item, function(paths)
    return vim.list_extend({ 'add', '--' }, paths)
  end, 'staged')
end

function A.git_restore()
  local item = A.current_item()
  vim.ui.input({ prompt = 'git restore ' .. ((item and item.name) or '') .. ': restore staged? (y/N): ' }, function(ans)
    local staged = ans and ans:lower() == 'y'
    git_op(item, function(paths)
      local args = { 'restore' }
      if staged then
        args[#args + 1] = '--staged'
      end
      return vim.list_extend(args, { '--' }, paths)
    end, 'restored')
  end)
end

-- ── Info popup ────────────────────────────────────────────────────────────

function A.file_info()
  local item = A.current_item()
  if not item then
    return
  end

  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(item.path)
  local ls = uv.fs_lstat(item.path)
  if not stat then
    vim.notify('[explorer] stat failed for ' .. item.path, vim.log.levels.WARN)
    return
  end

  -- Format file size
  local function fmt_size(n)
    if n < 1024 then
      return n .. ' B'
    elseif n < 1024 ^ 2 then
      return string.format('%.1f KiB', n / 1024)
    elseif n < 1024 ^ 3 then
      return string.format('%.1f MiB', n / 1024 ^ 2)
    else
      return string.format('%.1f GiB', n / 1024 ^ 3)
    end
  end

  -- Format timestamp
  local function fmt_time(sec)
    return sec and os.date('%Y-%m-%d  %H:%M:%S', sec) or '—'
  end

  -- Permissions (Unix octal → rwxrwxrwx)
  local function fmt_perm(mode)
    if not mode then
      return '—'
    end
    local bits = { 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' }
    local s = ''
    for i = 8, 0, -1 do
      s = s .. (bit.band(mode, 2 ^ i) ~= 0 and bits[9 - i] or '-')
    end
    return string.format('%o  (%s)', bit.band(mode, 0x1ff), s)
  end

  local lines = {
    '  ' .. fn.fnamemodify(item.path, ':~'),
    '  ' .. string.rep('─', 42),
  }
  local function row(label, val)
    lines[#lines + 1] = ('  %-14s  %s'):format(label, tostring(val))
  end

  row('Type', stat.type .. (ls and ls.type == 'link' and '  (symlink)' or ''))
  row('Size', item.is_dir and '—' or fmt_size(stat.size))
  row('Modified', fmt_time(stat.mtime and stat.mtime.sec))
  row('Created', fmt_time(stat.birthtime and stat.birthtime.sec))
  row('Accessed', fmt_time(stat.atime and stat.atime.sec))
  if vim.fn.has 'win32' == 0 then
    row('Permissions', fmt_perm(stat.mode))
    row('Owner UID', stat.uid)
    row('Group GID', stat.gid)
    row('Hard links', stat.nlink)
  end
  -- Symlink target
  if ls and ls.type == 'link' then
    local target = uv.fs_readlink(item.path)
    row('→ target', target or '?')
  end
  -- Git status
  local ch = S.git[item.path]
  if ch then
    local labels = {
      M = 'Modified',
      A = 'Added (staged)',
      D = 'Deleted',
      R = 'Renamed',
      ['?'] = 'Untracked',
      U = 'Conflict',
      I = 'Ignored',
    }
    row('Git status', labels[ch] or ch)
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = '  q / <Esc> / <CR> to close'

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Make the title just the filename
  local title = ' ' .. fn.fnamemodify(item.path, ':t') .. ' '
  local w = math.max(50, math.min(70, vim.o.columns - 10))
  local h = #lines
  local info_win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
  })

  -- Highlight the header
  local ns = api.nvim_create_namespace 'explorer_info'
  api.nvim_buf_add_highlight(buf, ns, 'Title', 0, 0, -1)
  api.nvim_buf_add_highlight(buf, ns, 'NonText', 1, 0, -1)

  local cls = function()
    pcall(api.nvim_win_close, info_win, true)
  end
  for _, k in ipairs { 'q', '<Esc>', '<CR>' } do
    vim.keymap.set('n', k, cls, { buffer = buf, silent = true })
  end
  api.nvim_create_autocmd('BufLeave', { buffer = buf, once = true, callback = cls })
end

-- ── Misc ──────────────────────────────────────────────────────────────────

function A.toggle_hidden()
  local c = cfg.get()
  c.show_hidden = not c.show_hidden
  render.render()
end

function A.copy_path()
  local item = A.current_item()
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

function A.refresh()
  git.fetch()
  render.render()
end

function A.show_help()
  local km = cfg.get().keymaps
  local function k(key)
    return type(key) == 'table' and table.concat(key, '/') or (key or '—')
  end
  local rows = {
    { '─── Navigation ─────────────────────────────────', '' },
    { k(km.open), 'open file / expand-collapse dir' },
    { k(km.close_dir), 'collapse dir / jump to parent' },
    { k(km.go_up), 'go up one level (re-root)' },
    { k(km.expand_all), 'expand all dirs (depth 1)' },
    { k(km.collapse_all), 'collapse all dirs' },
    { '', '' },
    { '─── Opening ────────────────────────────────────', '' },
    { k(km.vsplit), 'open in vertical split' },
    { k(km.split), 'open in horizontal split' },
    { k(km.tab), 'open in new tab' },
    { '', '' },
    { '─── File ops ───────────────────────────────────', '' },
    { k(km.add), 'add file (end with / = directory)' },
    { k(km.delete), 'delete  (respects marks)' },
    { k(km.rename), 'rename / move' },
    { k(km.copy), 'copy    (respects marks)' },
    { '', '' },
    { '─── Search & marks ─────────────────────────────', '' },
    { k(km.search), 'open live filter / search' },
    { 'Esc (in search)', 'clear filter and close search bar' },
    { k(km.mark), 'toggle mark on file (multi-select)' },
    { '', '' },
    { '─── Git ────────────────────────────────────────', '' },
    { k(km.git_stage), 'git add (stage)' },
    { k(km.git_restore), 'git restore (unstage / discard)' },
    { '', '' },
    { '─── Misc ───────────────────────────────────────', '' },
    { k(km.file_info), 'file info popup' },
    { k(km.copy_path), 'copy path to clipboard' },
    { k(km.toggle_hidden), 'toggle hidden files' },
    { k(km.refresh), 'refresh tree + git' },
    { k(km.quit), 'close explorer' },
    { k(km.help), 'this help' },
  }

  local lines = {}
  for _, r in ipairs(rows) do
    if r[2] == '' then
      lines[#lines + 1] = '  ' .. r[1]
    else
      lines[#lines + 1] = ('  %-16s  %s'):format(r[1], r[2])
    end
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = '  q / ? / <Esc> to close'

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local w, h = 58, #lines
  local hw = api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    title = ' Explorer Help ',
    title_pos = 'center',
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
  })

  -- Dim section headers
  local ns = api.nvim_create_namespace 'explorer_help'
  for i, r in ipairs(rows) do
    if r[2] == '' and r[1] ~= '' then
      api.nvim_buf_add_highlight(buf, ns, 'Comment', i - 1, 0, -1)
    end
  end

  local cls = function()
    pcall(api.nvim_win_close, hw, true)
  end
  for _, k2 in ipairs { 'q', '?', '<CR>', '<Esc>' } do
    vim.keymap.set('n', k2, cls, { buffer = buf, silent = true })
  end
  api.nvim_create_autocmd('BufLeave', { buffer = buf, once = true, callback = cls })
end

return A
