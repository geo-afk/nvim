local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local render = require("custom.explorer.render")
local git = require("custom.explorer.git")
local marks = require("custom.explorer.marks")
local store = require("custom.explorer.project_store")
local ui = require("custom.explorer.ui")

local api = vim.api
local fn = vim.fn

local A = {}

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

function A.current_item()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return nil
  end
  local row = api.nvim_win_get_cursor(S.win)[1] -- 1-based
  if row < 2 then
    return nil
  end
  return S.items[row - 1]
end

function A.jump_to(path)
  for i, it in ipairs(S.items) do
    if it.path == path then
      pcall(api.nvim_win_set_cursor, S.win, { i + 1, 0 }) -- line i+1
      return true
    end
  end
  return false
end

local function target_win()
  local function usable(w)
    if w == S.win then
      return false
    end
    local bt = vim.bo[api.nvim_win_get_buf(w)].buftype
    return bt == "" or bt == "nowrite"
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
    vim.cmd((cfg.get().side == "right" and "aboveleft" or "belowright") .. " vsplit")
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

function A.expand_all(max_depth)
  max_depth = max_depth or 1
  local function expand(path, depth)
    if depth > max_depth then
      return
    end
    local uv = vim.uv
    local handle = uv.fs_scandir(path)
    if not handle then
      return
    end
    while true do
      local name, t = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if t == "directory" then
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
    -- Check for trailing slash BEFORE tree.norm strips it — that's what
    -- signals "the user wants a directory".
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
  local mc = marks.count()

  local paths
  if mc > 0 then
    paths = vim.tbl_keys(require("custom.explorer.state").marks)
  elseif item then
    paths = { item.path }
  else
    return
  end

  if #paths == 0 then
    return
  end

  local label = mc > 0 and (mc .. " marked item" .. (mc == 1 and "" or "s"))
    or fn.fnamemodify(paths[1], ":t") .. (item and item.is_dir and "/" or "")

  -- Use popup confirmation instead of vim.ui.input
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
      local stat = vim.uv.fs_stat(p)
      if stat then
        local flags = stat.type == "directory" and "rf" or ""
        local ok = fn.delete(p, flags)
        if ok ~= 0 then
          vim.notify("[explorer] failed to delete: " .. p, vim.log.levels.ERROR)
        end
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
    fn.mkdir(tree.parent(dest), "p")
    if fn.rename(item.path, dest) ~= 0 then
      vim.notify("[explorer] rename failed: " .. item.path .. " → " .. dest, vim.log.levels.ERROR)
      return
    end
    for _, client in ipairs(vim.lsp.get_clients()) do
      -- Check if the server supports the 'didRename' file operation notification
      local file_ops = client.server_capabilities.workspace and client.server_capabilities.workspace.fileOperations
      if file_ops and file_ops.didRename then
        local method = vim.lsp.protocol.Methods.workspace_didRenameFiles
        client.notify(method, {
          files = {
            {
              oldUri = vim.uri_from_fname(item.path),
              newUri = vim.uri_from_fname(dest),
            },
          },
        })
      end
    end
    A.refresh()
    vim.schedule(function()
      require("custom.explorer").reveal(dest)
    end)
  end)
end

function A.copy()
  local item = A.current_item()
  local paths = marks.selection(item)
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
      fn.mkdir(tree.parent(dest), "p")
      local is_dir = vim.uv.fs_stat(paths[1])
      local cmd = (is_dir and is_dir.type == "directory") and { "cp", "-r", paths[1], dest } or { "cp", paths[1], dest }
      vim.system(cmd, {}, function(out)
        vim.schedule(function()
          if out.code ~= 0 then
            vim.notify("[explorer] copy failed: " .. (out.stderr or ""), vim.log.levels.ERROR)
          else
            A.refresh()
          end
        end)
      end)
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
      local cmds = {}
      for _, p in ipairs(paths) do
        cmds[#cmds + 1] = { "cp", "-r", p, dest }
      end
      local function run(i)
        if i > #cmds then
          marks.clear()
          A.refresh()
          return
        end
        vim.system(cmds[i], {}, function()
          vim.schedule(function()
            run(i + 1)
          end)
        end)
      end
      run(1)
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
  local max = #S.items + 1 -- last item is at line #items+1
  if max >= 2 then
    pcall(api.nvim_win_set_cursor, S.win, { math.min(row + 1, max), 0 })
  end
end

function A.clear_filter()
  require("custom.explorer.search").clear()
end

local function git_op(item, args_fn, msg)
  local paths = marks.selection(item)
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
function A.git_restore()
  local item = A.current_item()
  vim.ui.input({ prompt = "git restore: restore staged? (y/N): " }, function(ans)
    local staged = ans and ans:lower() == "y"
    git_op(item, function(p)
      local a = { "restore" }
      if staged then
        a[#a + 1] = "--staged"
      end
      a[#a + 1] = "--"
      -- vim.list_extend(dst, src) — only two meaningful args here;
      -- the old call passed `p` (a table) as the integer start-index.
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
  -- cfg.get() may return a shallow copy when tree is unresolved, so we must
  -- write back to the authoritative source to make the change stick.
  local c = cfg.current or cfg.defaults
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
  git.fetch()
  render.render()
end

function A.add_project()
  local root = S.root
  if not root or root == "" then
    return
  end

  if store.is_pinned(root) then
    vim.notify("[explorer] project already pinned: " .. vim.fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
    return
  end

  store.add_pinned(root)
  vim.notify("[explorer] pinned project: " .. vim.fn.fnamemodify(root, ":~"), vim.log.levels.INFO)
end

function A.show_help()
  ui.help()
end

return A
