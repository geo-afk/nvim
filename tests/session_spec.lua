local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
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
write_file(file_a, "alpha")
write_file(file_b, "beta")
write_file(file_c, "gamma")

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
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == "" and not vim.bo[bufnr].modified then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
      end
    end
  end
  vim.cmd("silent! enew")
end

local function visible_paths()
  local seen = {}
  local out = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf):gsub("\\", "/")
      if name ~= "" and not seen[name] then
        seen[name] = true
        out[#out + 1] = name
      end
    end
  end
  table.sort(out)
  return out
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
  vim.cmd("vsplit " .. vim.fn.fnameescape(file_b))
  vim.cmd("tabnew " .. vim.fn.fnameescape(file_c))
end

local function run()
  build_state()

  assert_ok(session.save({ silent = true }), "session save should succeed")
  local saved = session.get_paths()
  assert_ok(vim.fn.filereadable(saved.session) == 1, "session file should exist")
  assert_ok(vim.fn.filereadable(saved.meta) == 1, "session metadata should exist")

  reset_layout()
  assert_ok(session.restore({ silent = true }), "session restore should succeed")
  assert_eq(#vim.api.nvim_list_tabpages(), 2, "restore should recreate two tabpages")
  assert_eq(#vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[1]), 2, "first tab should have a split")
  assert_eq(visible_paths(), { file_a, file_b, file_c }, "restore should reopen all files")

  os.remove(file_b)
  reset_layout()
  assert_ok(session.restore({ silent = true }), "session restore should tolerate missing files")
  assert_eq(#vim.api.nvim_list_tabpages(), 2, "missing-file restore should keep tabpages stable")
  assert_eq(visible_paths(), { file_a, file_c }, "missing file should be cleaned up after restore")

  local ordered = listed_paths()
  assert_eq(ordered[1], file_a, "tabline order should preserve first buffer")
  assert_eq(ordered[#ordered], file_c, "tabline order should preserve final visible buffer")
end

local success, err = xpcall(run, debug.traceback)
vim.fn.delete(root, "rf")
if not success then
  error(err)
end
