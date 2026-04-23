local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local root = vim.fn.tempname():gsub("\\", "/")
vim.fn.mkdir(root, "p")
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

local original_system = vim.system
vim.system = function(_, _, on_exit)
  local result = { code = 1, stdout = "", stderr = "" }
  if on_exit then
    vim.schedule(function()
      on_exit(result)
    end)
  end
  return {
    wait = function()
      return result
    end,
  }
end

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

local function wait_for(message, predicate)
  local ok = vim.wait(2000, predicate, 20)
  assert_ok(ok, message)
end

local file_main = path("alpha.txt")
local file_other = path("beta.txt")
local folder_one = path("one")
local folder_two = path("two")
write_file(file_main, "alpha")
write_file(file_other, "beta")
vim.fn.mkdir(folder_one, "p")
vim.fn.mkdir(folder_two, "p")
write_file(path("one", "nested.txt"), "nested")

vim.cmd("cd " .. vim.fn.fnameescape(root))
vim.cmd("edit " .. vim.fn.fnameescape(file_main))

local ok_explorer, explorer = pcall(require, "custom.explorer")
assert_ok(ok_explorer, explorer)
local ok_state, S = pcall(require, "custom.explorer.state")
assert_ok(ok_state, S)
local ok_actions, actions = pcall(require, "custom.explorer.actions")
assert_ok(ok_actions, actions)
local ok_search, search = pcall(require, "custom.explorer.search")
assert_ok(ok_search, search)
local ok_move, move = pcall(require, "custom.explorer.move")
assert_ok(ok_move, move)

explorer.setup({
  follow_file = false,
  width = 60,
})

local function cleanup()
  vim.system = original_system
  pcall(explorer.close, { wipe = true })
  vim.cmd("silent! only")
  vim.cmd("silent! enew")
  vim.fn.delete(root, "rf")
end

local function run()
  explorer.open({ root = root })

  wait_for("explorer should populate items", function()
    return S.win and vim.api.nvim_win_is_valid(S.win) and #S.items >= 4
  end)

  search.activate()

  wait_for("search should render its result list while active", function()
    local lines = vim.api.nvim_buf_get_lines(S.buf, 0, -1, false)
    return S.search_active and #lines > 2 and lines[2] ~= nil and lines[2] ~= ""
  end)

  search.clear()
  vim.api.nvim_set_current_win(S.win)

  wait_for("search should exit cleanly before move flow starts", function()
    return not S.search_active and vim.api.nvim_get_current_win() == S.win
  end)

  vim.api.nvim_win_set_cursor(S.win, { 2, 0 })
  actions.move()

  wait_for("move picker should open as a floating window", function()
    local current = vim.api.nvim_get_current_win()
    return current ~= S.win and vim.api.nvim_win_get_config(current).relative ~= ""
  end)

  move.close()

  wait_for("closing move picker should restore focus to explorer", function()
    return S.win and vim.api.nvim_win_is_valid(S.win) and vim.api.nvim_get_current_win() == S.win
  end)

  wait_for("closing move picker should leave explorer in normal mode", function()
    return vim.api.nvim_get_mode().mode == "n"
  end)

  vim.api.nvim_win_set_cursor(S.win, { 2, 0 })
  vim.cmd("normal! j")

  wait_for("explorer navigation should work after the move picker closes", function()
    return vim.api.nvim_win_get_cursor(S.win)[1] == 3
  end)
end

local success, err = xpcall(run, debug.traceback)
cleanup()
if not success then
  error(err)
end
