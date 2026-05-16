local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(
      (message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual)
    )
  end
end

local root = vim.fn.tempname():gsub("\\", "/")
vim.fn.mkdir(root, "p")

local function path(...)
  local parts = { root }
  for _, piece in ipairs({ ... }) do
    parts[#parts + 1] = piece
  end
  return table.concat(parts, "/")
end

local function write_file(file, text)
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  local fd = assert(io.open(file, "wb"))
  fd:write(text or "")
  fd:close()
end

local ok, actions = pcall(require, "custom.explorer.actions")
assert_ok(ok, actions)
vim.lsp.get_clients = function()
  return {}
end

local function run()
  local src_dir = path("src")
  local dest_dir = path("dest")
  vim.fn.mkdir(src_dir, "p")
  vim.fn.mkdir(dest_dir, "p")

  local file_a = path("src", "alpha.txt")
  local file_b = path("src", "beta.txt")
  write_file(file_a, "alpha")
  write_file(file_b, "beta")

  local moved_ok, moved = actions._move_paths({ file_a, file_b }, dest_dir)
  assert_ok(moved_ok, moved)
  assert_eq(#moved, 2, "expected both files to move")
  assert_eq(vim.uv.fs_stat(path("dest", "alpha.txt")).type, "file", "alpha should exist in destination")
  assert_ok(vim.uv.fs_stat(file_a) == nil, "alpha should no longer exist in source")

  local parent_dir = path("parent")
  local child_dir = path("parent", "child")
  vim.fn.mkdir(child_dir, "p")

  local blocked_ok, blocked_err = actions._move_paths({ parent_dir }, child_dir)
  assert_ok(not blocked_ok, "moving a directory into itself should fail")
  assert_ok(tostring(blocked_err):find("cannot move a folder into itself", 1, true) ~= nil, "expected self-move guard")

  local conflict_src = path("conflict.txt")
  local conflict_dest = path("dest", "conflict.txt")
  write_file(conflict_src, "one")
  write_file(conflict_dest, "two")

  local conflict_ok, conflict_err = actions._move_paths({ conflict_src }, dest_dir)
  assert_ok(not conflict_ok, "move should fail when destination exists")
  assert_ok(tostring(conflict_err):find("destination already exists", 1, true) ~= nil, "expected conflict guard")
end

local success, err = xpcall(run, debug.traceback)
vim.fn.delete(root, "rf")
if not success then
  error(err)
end
