-- custom/explorer/actions.lua

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local render = require("custom.explorer.render")
local git = require("custom.explorer.git")
local marks = require("custom.explorer.marks")
local move_picker = require("custom.explorer.move")
local store = require("custom.explorer.project_store")
local ui = require("custom.explorer.ui")
local search_ui = require("custom.explorer.search_ui")

local api = vim.api
local fn = vim.fn

local A = {}

local function path_exists(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

local function shell_quote_pwsh(path)
  return "'" .. tostring(path):gsub("'", "''") .. "'"
end

local function selected_paths(paths)
  local seen = {}
  local out = {}
  table.sort(paths, function(a, b)
    if #a ~= #b then
      return #a < #b
    end
    return a < b
  end)
  for _, path in ipairs(paths) do
    path = tree.norm(path)
    if path ~= "" and not seen[path] and path_exists(path) then
      local nested = false
      for _, kept in ipairs(out) do
        if path == kept or vim.startswith(path, kept .. "/") then
          nested = true
          break
        end
      end
      if not nested then
        seen[path] = true
        out[#out + 1] = path
      end
    end
  end
  return out
end

local function is_explorer_like_buffer(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  local ft = vim.bo[buf].filetype
  return ft == "explorer" or ft == "explorer_projects" or ft == "explorer_prompt" or ft == "explorer_popup"
end

local function rel_to_root(path)
  if not S.root or not path then
    return path
  end
  if path == S.root then
    return ""
  end
  local prefix = S.root .. "/"
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end
  return path
end

local function copy_file(src, dest)
  local parent = tree.parent(dest)
  if parent and parent ~= "" then
    fn.mkdir(parent, "p")
  end
  local ok, err = vim.uv.fs_copyfile(src, dest)
  if ok then
    return true
  end
  local in_f = io.open(src, "rb")
  if not in_f then
    return false, err or ("failed to open source: " .. src)
  end
  local data = in_f:read("*a")
  in_f:close()
  local out_f = io.open(dest, "wb")
  if not out_f then
    return false, "failed to open destination: " .. dest
  end
  out_f:write(data)
  out_f:close()
  return true
end

local function copy_dir_recursive(src, dest)
  fn.mkdir(dest, "p")
  local handle = vim.uv.fs_scandir(src)
  if not handle then
    return false, "failed to scan directory: " .. src
  end
  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local from = tree.join(src, name)
    local to = tree.join(dest, name)
    if entry_type == "directory" then
      local ok, err = copy_dir_recursive(from, to)
      if not ok then
        return false, err
      end
    else
      local ok, err = copy_file(from, to)
      if not ok then
        return false, err
      end
    end
  end
  return true
end

local is_subpath

local function copy_path(src, dest)
  local stat = vim.uv.fs_stat(src)
  if not stat then
    return false, "missing source: " .. src
  end
  src = tree.norm(src)
  dest = tree.norm(dest)
  if dest == src then
    return false, "destination is the same as source: " .. src
  end
  if vim.uv.fs_stat(dest) then
    return false, "destination already exists: " .. dest
  end
  if stat.type == "directory" then
    if is_subpath(dest, src) then
      return false, "cannot copy a folder into itself: " .. src
    end
    return copy_dir_recursive(src, dest)
  end
  return copy_file(src, dest)
end

is_subpath = function(path, parent)
  if not path or not parent then
    return false
  end
  path = tree.norm(path)
  parent = tree.norm(parent)
  return path == parent or vim.startswith(path, parent .. "/")
end

local function delete_path(path)
  if not path_exists(path) then
    return true
  end

  if cfg.get().delete_to_trash ~= false then
    if fn.has("win32") == 1 then
      local is_dir = vim.uv.fs_stat(path).type == "directory"
      local cmd = is_dir
          and ([[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(%s, 'OnlyErrorDialogs', 'SendToRecycleBin')]]):format(
            shell_quote_pwsh(path)
          )
        or ([[Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(%s, 'OnlyErrorDialogs', 'SendToRecycleBin')]]):format(
          shell_quote_pwsh(path)
        )
      local out = vim.system({ "powershell", "-NoProfile", "-NonInteractive", "-Command", cmd }, { text = true }):wait()
      if out.code == 0 then
        return true
      end
      return false,
        (out.stderr and vim.trim(out.stderr) ~= "" and vim.trim(out.stderr)) or "failed to move to recycle bin"
    end

    for _, cmd in ipairs({
      { "gio", "trash", path },
      { "trash-put", path },
      { "trash", path },
    }) do
      if fn.executable(cmd[1]) == 1 then
        local out = vim.system(cmd, { text = true }):wait()
        if out.code == 0 then
          return true
        end
      end
    end
  end

  local stat = vim.uv.fs_stat(path)
  if not stat then
    return true
  end
  local flags = stat.type == "directory" and "rf" or ""
  if fn.delete(path, flags) == 0 then
    return true
  end
  return false, "failed to delete: " .. path
end

local function notify_lsp_rename(old_path, new_path)
  for _, client in ipairs(vim.lsp.get_clients()) do
    local file_ops = client.server_capabilities.workspace and client.server_capabilities.workspace.fileOperations
    if file_ops and file_ops.didRename then
      client.notify(vim.lsp.protocol.Methods.workspace_didRenameFiles, {
        files = {
          {
            oldUri = vim.uri_from_fname(old_path),
            newUri = vim.uri_from_fname(new_path),
          },
        },
      })
    end
  end
end

local function move_paths(paths, dest_dir)
  paths = selected_paths(paths)
  dest_dir = tree.norm(dest_dir or "")
  if dest_dir == "" then
    return false, "missing destination folder"
  end

  local stat = vim.uv.fs_stat(dest_dir)
  if not stat or stat.type ~= "directory" then
    return false, "destination is not a directory: " .. dest_dir
  end

  local moved = {}
  for _, src in ipairs(paths) do
    local dest = tree.join(dest_dir, fn.fnamemodify(src, ":t"))
    if dest == src then
      return false, "source is already in that folder: " .. src
    end
    if is_subpath(dest, src) then
      return false, "cannot move a folder into itself: " .. src
    end
    if vim.uv.fs_stat(dest) then
      return false, "destination already exists: " .. dest
    end
    fn.mkdir(tree.parent(dest), "p")
    if fn.rename(src, dest) ~= 0 then
      return false, "move failed: " .. src .. " -> " .. dest
    end
    moved[#moved + 1] = { old = src, new = dest }
  end

  for _, item in ipairs(moved) do
    notify_lsp_rename(item.old, item.new)
  end

  return true, moved
end

function A.current_item()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil
  end
  local row = api.nvim_win_get_cursor(S.win)[1] -- 1-based
  local idx = search_ui.item_index_from_line(row)
  if not idx then
    return nil
  end
  return S.items[idx]
end

function A.jump_to(path)
  for i, it in ipairs(S.items) do
    if it.path == path then
      pcall(api.nvim_win_set_cursor, S.win, { search_ui.line_for_item(i), 0 })
      return true
    end
  end
  return false
end

local function target_win()
  local function usable(w)
    if not (w and api.nvim_win_is_valid(w)) then
      return false
    end
    if w == S.win then
      return false
    end
    if api.nvim_win_get_config(w).relative ~= "" then
      return false
    end
    local buf = api.nvim_win_get_buf(w)
    if is_explorer_like_buffer(buf) then
      return false
    end
    if vim.bo[buf].buftype ~= "" then
      return false
    end
    if vim.wo[w].previewwindow then
      return false
    end
    return true
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

-- Export so search.lua can use it for <CR> open-in-place
A.target_win = target_win

local function open_in(path, cmd)
  local tw = target_win()
  if tw then
    api.nvim_set_current_win(tw)
  else
    vim.cmd((cfg.get().side == "right" and "aboveleft" or "belowright") .. " vsplit")
    tw = api.nvim_get_current_win()
  end
  if tw and api.nvim_win_is_valid(tw) then
    S.prev_win = tw
  end
  vim.cmd(cmd .. " " .. fn.fnameescape(path))
end

function A.open_or_toggle()
  local item = A.current_item()
  if not item then
    return
  end
  if item.is_dir then
    S.open_dirs[item.path] = not S.open_dirs[item.path] or nil
    render.render()
  else
    open_in(item.path, "edit")
    if S.win and api.nvim_win_is_valid(S.win) then
      vim.schedule(function()
        if S.win and api.nvim_win_is_valid(S.win) and A.current_item() == nil and #S.items > 0 then
          pcall(api.nvim_win_set_cursor, S.win, { search_ui.line_for_item(1), 0 })
        end
      end)
    end
    if cfg.get().auto_close then
      require("custom.explorer").close()
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
  S.open_dirs[old] = true
  render.render()
  git.fetch()
  require("custom.explorer.win").update_winbar()
  vim.schedule(function()
    A.jump_to(old)
  end)
end

function A.collapse_all()
  S.open_dirs = {}
  render.render()
end

-- FIX: was synchronous uv.fs_scandir in a tight loop — blocked the main
-- thread on large directory trees.  Now uses async fs_scandir with a
-- recursive continuation so Neovim stays responsive throughout.
function A.expand_all(max_depth)
  max_depth = max_depth or 1
  S.open_dirs = {}

  local function expand_async(path, depth, done)
    if depth > max_depth then
      done()
      return
    end
    vim.uv.fs_scandir(
      path,
      vim.schedule_wrap(function(err, handle)
        if err or not handle then
          done()
          return
        end
        local subdirs = {}
        while true do
          local name, t = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end
          if t == "directory" then
            local abs = tree.join(path, name)
            S.open_dirs[abs] = true
            subdirs[#subdirs + 1] = abs
          end
        end
        -- Process subdirectories sequentially to avoid stack overflow on
        -- deeply nested trees and to keep the I/O observable.
        local i = 0
        local function next_dir()
          i = i + 1
          if i > #subdirs then
            done()
          else
            expand_async(subdirs[i], depth + 1, next_dir)
          end
        end
        next_dir()
      end)
    )
  end

  expand_async(S.root, 1, function()
    render.render()
  end)
end

function A.vsplit()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, "vsplit")
  end
end
function A.split()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, "split")
  end
end
function A.tab_open()
  local i = A.current_item()
  if i and not i.is_dir then
    open_in(i.path, "tabedit")
  end
end

function A.add()
  local item = A.current_item()
  local dir = item and (item.is_dir and item.path or tree.parent(item.path)) or S.root
  local default = rel_to_root(dir)
  if default ~= "" then
    default = default .. "/"
  end
  ui.rooted_path_input({
    title = " New Entry ",
    prompt = "Create: ",
    root = S.root,
    default = default,
    footer = " finish with / for a directory ",
  }, function(name)
    if not name or name == "" then
      return
    end
    -- Check for trailing slash BEFORE tree.norm strips it —
    -- that's what signals "the user wants a directory".
    local is_dir = vim.endswith(name, "/")
    name = tree.norm(name)
    if name == "" then
      return
    end
    if is_dir then
      if fn.mkdir(name, "p") == 0 then
        vim.notify("[explorer] failed to create directory: " .. name, vim.log.levels.ERROR)
        return
      end
    else
      fn.mkdir(tree.parent(name), "p")
      local f = io.open(name, "w")
      if not f then
        vim.notify("[explorer] failed to create file: " .. name, vim.log.levels.ERROR)
        return
      end
      f:close()
    end
    A.refresh()
    vim.schedule(function()
      require("custom.explorer").reveal(name)
    end)
  end)
end

function A.delete()
  local item = A.current_item()
  marks.prune()
  local mc = marks.count()

  local paths
  if mc > 0 then
    paths = vim.tbl_keys(require("custom.explorer.state").marks)
  elseif item then
    paths = { item.path }
  else
    return
  end
  paths = selected_paths(paths)
  if #paths == 0 then
    return
  end

  local label = mc > 0 and (mc .. " marked item" .. (mc == 1 and "" or "s"))
    or (fn.fnamemodify(paths[1], ":t") .. (item and item.is_dir and "/" or ""))

  ui.confirm({
    prompt = "Delete " .. label,
    title = " Delete Confirmation ",
    footer = " y delete   <Esc> cancel ",
    danger = true,
  }, function(confirmed)
    if not confirmed then
      return
    end
    for _, p in ipairs(paths) do
      local ok, err = delete_path(p)
      if not ok then
        vim.notify("[explorer] " .. tostring(err), vim.log.levels.ERROR)
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
  ui.rooted_path_input({
    title = " Rename / Move ",
    prompt = "Rename to: ",
    root = S.root,
    default = item.path,
  }, function(dest)
    if not dest or dest == "" or dest == item.path then
      return
    end
    dest = tree.norm(dest)
    if vim.uv.fs_stat(dest) then
      vim.notify("[explorer] rename target already exists: " .. dest, vim.log.levels.ERROR)
      return
    end
    if item.is_dir and is_subpath(dest, item.path) then
      vim.notify("[explorer] cannot move a folder into itself: " .. item.path, vim.log.levels.ERROR)
      return
    end
    fn.mkdir(tree.parent(dest), "p")
    if fn.rename(item.path, dest) ~= 0 then
      vim.notify("[explorer] rename failed: " .. item.path .. " → " .. dest, vim.log.levels.ERROR)
      return
    end
    notify_lsp_rename(item.path, dest)
    marks.replace(item.path, dest)
    A.refresh()
    vim.schedule(function()
      require("custom.explorer").reveal(dest)
    end)
  end)
end

A._move_paths = move_paths

function A.move()
  local item = A.current_item()
  marks.prune()
  local mc = marks.count()

  -- Mirrors A.delete(): include directories in the fallback (single-item) path.
  -- marks.selection() blocks directories to protect bulk-mark workflows, but
  -- for explicit single-item moves the user should be able to move any entry.
  local paths
  if mc > 0 then
    paths = vim.tbl_keys(S.marks)
  elseif item then
    paths = { item.path }
  else
    return
  end
  paths = selected_paths(paths)
  if #paths == 0 then
    return
  end

  move_picker.open({
    start_dir = #paths == 1 and tree.parent(paths[1]) or S.root,
    on_confirm = function(dest_dir)
      local ok, result = move_paths(paths, dest_dir)
      if not ok then
        vim.notify("[explorer] " .. tostring(result), vim.log.levels.ERROR)
        return
      end
      marks.clear()
      A.refresh()
      local last = result[#result]
      if last then
        vim.schedule(function()
          require("custom.explorer").reveal(last.new)
        end)
      end
      vim.notify("[explorer] moved " .. #result .. " item" .. (#result == 1 and "" or "s"), vim.log.levels.INFO)
    end,
  })
end

function A.copy()
  local item = A.current_item()
  local paths = marks.selection(item)
  paths = selected_paths(paths)
  if #paths == 0 then
    return
  end
  if #paths == 1 then
    ui.rooted_path_input({
      title = " Copy Entry ",
      prompt = "Copy to: ",
      root = S.root,
      default = paths[1],
    }, function(dest)
      if not dest or dest == "" or dest == paths[1] then
        return
      end
      dest = tree.norm(dest)
      local ok, err = copy_path(paths[1], dest)
      if not ok then
        vim.notify("[explorer] copy failed: " .. tostring(err), vim.log.levels.ERROR)
        return
      end
      A.refresh()
    end)
  else
    ui.rooted_path_input({
      title = " Copy Marked Entries ",
      prompt = "Copy " .. #paths .. " items to: ",
      root = S.root,
      default = "",
    }, function(dest)
      if not dest or dest == "" then
        return
      end
      dest = tree.norm(dest)
      fn.mkdir(dest, "p")
      for _, p in ipairs(paths) do
        local target = tree.join(dest, fn.fnamemodify(p, ":t"))
        local ok, err = copy_path(p, target)
        if not ok then
          vim.notify("[explorer] copy failed: " .. tostring(err), vim.log.levels.ERROR)
          return
        end
      end
      marks.clear()
      A.refresh()
    end)
  end
end

function A.toggle_mark()
  local item = A.current_item()
  if not item then
    return
  end
  marks.toggle(item)
  local row = api.nvim_win_get_cursor(S.win)[1]
  local max = #S.items + 1
  if max >= 2 then
    pcall(api.nvim_win_set_cursor, S.win, { math.min(row + 1, max), 0 })
  end
end

function A.clear_filter()
  require("custom.explorer.search").clear()
end

local function git_op(item, args_fn, msg)
  local paths = marks.selection(item)
  paths = selected_paths(paths)
  if #paths == 0 then
    return
  end
  vim.system(vim.list_extend({ "git", "-C", S.root }, args_fn(paths)), { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify("[explorer] git error:\n" .. (out.stderr or ""), vim.log.levels.ERROR)
      else
        if msg then
          vim.notify("[explorer] " .. msg, vim.log.levels.INFO)
        end
        marks.clear()
        git.fetch()
      end
    end)
  end)
end

function A.git_stage()
  git_op(A.current_item(), function(p)
    return vim.list_extend({ "add", "--" }, p)
  end, "staged")
end

-- FIX: was vim.ui.input — inconsistent with the rest of the UI.
-- Now uses ui.confirm to match the plugin's own popup style.
function A.git_restore()
  local item = A.current_item()
  ui.confirm({
    title = " Git Restore ",
    prompt = "Also restore staged changes?",
    footer = " y yes   <Esc> no (working tree only) ",
  }, function(include_staged)
    git_op(item, function(p)
      local a = { "restore" }
      if include_staged then
        a[#a + 1] = "--staged"
      end
      a[#a + 1] = "--"
      return vim.list_extend(a, p)
    end, "restored")
  end)
end

function A.file_info()
  local item = A.current_item()
  if not item then
    return
  end
  ui.file_info(item)
end

function A.toggle_hidden()
  -- cfg.get() may return a shallow copy; write to the authoritative source
  local c = cfg.current or cfg.defaults
  c.show_hidden = not c.show_hidden
  render.render()
end

function A.toggle_width()
  require("custom.explorer.win").toggle_width()
end

function A.copy_path()
  local item = A.current_item()
  if not item then
    return
  end
  local p = item.path
  vim.ui.select({
    { label = "Absolute", val = p },
    { label = "Relative to CWD", val = fn.fnamemodify(p, ":.") },
    { label = "Home-relative", val = fn.fnamemodify(p, ":~") },
    { label = "Filename", val = fn.fnamemodify(p, ":t") },
    { label = "Stem (no ext)", val = fn.fnamemodify(p, ":t:r") },
  }, {
    prompt = "Copy path:",
    format_item = function(o)
      return ("%-20s  %s"):format(o.label, o.val)
    end,
  }, function(choice)
    if not choice then
      return
    end
    fn.setreg("+", choice.val)
    fn.setreg('"', choice.val)
    vim.notify("[explorer] " .. choice.val, vim.log.levels.INFO)
  end)
end

function A.refresh()
  marks.prune()
  git.fetch()
  render.render()
end

function A.add_project()
  local root = S.root
  if not root or root == "" then
    return
  end
  if store.is_pinned(root) then
    vim.notify("[explorer] project already pinned: " .. fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
    return
  end
  store.add_pinned(root)
  vim.notify("[explorer] pinned project: " .. fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
end

function A.show_help()
  ui.help()
end

return A
