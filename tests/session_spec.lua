local root_dir = vim.fn.getcwd():gsub("\\", "/")
package.path = package.path .. ";" .. root_dir .. "/lua/?.lua;" .. root_dir .. "/lua/?/init.lua"

local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(
      (message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual)
    )
  end
end

local root = vim.fn.tempname():gsub("\\", "/")
vim.fn.mkdir(root, "p")
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

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

local file_a = path("a.txt")
local file_b = path("b.txt")
local file_c = path("nested", "c.txt")
local other_root = path("other-project")
local other_file = path("other-project", "main.txt")
write_file(file_a, "alpha")
write_file(file_b, "beta")
write_file(file_c, "gamma")
write_file(other_file, "delta")

vim.cmd("cd " .. vim.fn.fnameescape(root))

local ok_session, session = pcall(require, "custom.session")
assert_ok(ok_session, session)
local ok_tabline, tabline_buffers = pcall(require, "custom.tabline.buffers")
assert_ok(ok_tabline, tabline_buffers)

session.setup({
  auto_restore = false,
  auto_save = false,
  notify = false,
  session_dir = path(".session"),
})

local function reset_layout()
  vim.cmd("silent! tabonly!")
  vim.cmd("silent! only")
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
  vim.cmd("silent! enew")
end

local function listed_paths()
  local out = {}
  for _, bufnr in ipairs(tabline_buffers.get_buffers()) do
    local name = vim.api.nvim_buf_get_name(bufnr):gsub("\\", "/")
    if name ~= "" then
      out[#out + 1] = name
    end
  end
  return out
end

local function build_state()
  vim.cmd("edit " .. vim.fn.fnameescape(file_a))
  vim.cmd("split " .. vim.fn.fnameescape(file_b))
  vim.cmd("tabedit " .. vim.fn.fnameescape(file_c))
end

local function run()
  build_state()
  assert_eq(#vim.api.nvim_list_tabpages(), 2, "setup should have 2 tabpages")
  assert_eq(#vim.api.nvim_list_wins(), 3, "setup should have 3 windows")

  assert_ok(session.save({ silent = true }), "session save should succeed")
  local saved = session.get_paths()
  assert_ok(vim.fn.filereadable(saved.vim) == 1, "session vim file should exist")
  assert_ok(vim.fn.filereadable(saved.meta) == 1, "session metadata should exist")

  reset_layout()
  assert_ok(session.restore({ silent = true }), "session restore should succeed")

  -- Verify windows/tabs are restored
  assert_eq(#vim.api.nvim_list_tabpages(), 2, "restore should recreate tabpages")
  assert_eq(#vim.api.nvim_list_wins(), 3, "restore should recreate windows")

  -- Verify custom order restoration
  local expected_order = { file_a, file_b, file_c }
  local actual_order = {}
  for _, b in ipairs(tabline_buffers.get_buffers()) do
    actual_order[#actual_order + 1] = vim.api.nvim_buf_get_name(b):gsub("\\", "/")
  end
  assert_eq(actual_order, expected_order, "custom tab order should be preserved")

  local listed = listed_paths()
  table.sort(listed)
  assert_eq(listed, { file_a, file_b, file_c }, "restore should reopen all files in buffer list")
  assert_eq(vim.api.nvim_buf_get_name(0):gsub("\\", "/"), file_c, "restore should set current buffer correctly")

  -- Test isolation
  vim.cmd("cd " .. vim.fn.fnameescape(other_root))
  reset_layout()
  vim.cmd("edit " .. vim.fn.fnameescape(other_file))
  assert_ok(session.save({ silent = true }), "other project session save should succeed")

  local other_saved = session.get_paths()
  assert_ok(saved.vim ~= other_saved.vim, "session files should be scoped per cwd")

  reset_layout()
  assert_ok(session.restore({ silent = true }), "other project restore should succeed")
  assert_eq(listed_paths(), { other_file }, "other project restore should only load that project's buffers")

  vim.cmd("cd " .. vim.fn.fnameescape(root))
  reset_layout()
  assert_ok(session.restore({ silent = true }), "original project restore should still succeed")
  assert_eq(#vim.api.nvim_list_tabpages(), 2, "original layout should be restored")
end

local success, err = xpcall(run, debug.traceback)
vim.fn.delete(root, "rf")
if not success then
  error(err)
end
