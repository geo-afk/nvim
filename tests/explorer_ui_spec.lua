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
local ok_search_ui, search_ui = pcall(require, "custom.explorer.search_ui")
assert_ok(ok_search_ui, search_ui)
local ok_win, explorer_win = pcall(require, "custom.explorer.win")
assert_ok(ok_win, explorer_win)

explorer.setup({
  follow_file = true,
  width = 60,
  projects = {
    store_path = path("projects.json"),
  },
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

  local other_buf = vim.fn.bufadd(file_other)
  vim.fn.bufload(other_buf)
  require("custom.tabline").switch_to_buffer(other_buf)
  wait_for("tabline buffer selection should synchronize the explorer", function()
    return S.active_buf_path == file_other
  end)
  assert_ok(vim.api.nvim_get_current_win() ~= S.win, "automatic synchronization must not steal editor focus")
  vim.api.nvim_set_current_win(S.win)

  assert_ok(S.search_win and vim.api.nvim_win_is_valid(S.search_win), "search overlay should be visible")
  local header_config = vim.api.nvim_win_get_config(S.search_win)
  assert_eq(header_config.relative, "editor", "fixed header should be managed inside the explorer rectangle")
  assert_eq(
    header_config.width,
    vim.api.nvim_win_get_width(S.win),
    "search and tree regions should have one authoritative width"
  )
  assert_eq(header_config.height, search_ui.HEADER_LINES, "header geometry should use the reserved tree rows")
  local header_lines = search_ui.header_lines("query")
  assert_ok(header_lines[1]:find("Files", 1, true), "modern header should retain a compact content label")
  for _, edge in ipairs({ "╭", "╮", "╰", "╯", "│" }) do
    assert_ok(
      not header_lines[1]:find(edge, 1, true) and not header_lines[2]:find(edge, 1, true),
      "integrated header must not render its own outer box"
    )
  end
  assert_ok(
    vim.wo[S.win].winhighlight:find("Normal:ExplorerNormal", 1, true)
      and vim.wo[S.search_win].winhighlight:find("Normal:ExplorerNormal", 1, true),
    "header and tree backgrounds should resolve through the same highlight"
  )
  assert_eq(header_config.style, "minimal", "fixed header should suppress statusline and auxiliary window UI")
  assert_eq(vim.wo[S.search_win].signcolumn, "no", "fixed header should not expose a sign column")
  local header_marks = vim.api.nvim_buf_get_extmarks(S.search_buf, S.hdr_ns, 0, -1, { details = true })
  local has_placeholder = false
  local has_filter_hint = false
  for _, mark in ipairs(header_marks) do
    for _, chunk in ipairs(mark[4].virt_text or {}) do
      has_placeholder = has_placeholder or chunk[1] == search_ui.placeholder_text()
      has_filter_hint = has_filter_hint or chunk[1]:find("/ filter", 1, true) ~= nil
    end
  end
  assert_ok(has_placeholder, "empty search input should render a real placeholder")
  assert_ok(has_filter_hint, "idle header should advertise the existing search action")

  local overlay_pos = vim.api.nvim_win_get_position(S.search_win)
  vim.api.nvim_win_call(S.win, function()
    vim.cmd("normal! G")
  end)
  local overlay_pos_after = vim.api.nvim_win_get_position(S.search_win)
  assert_eq(overlay_pos_after[1], overlay_pos[1], "search overlay row should remain fixed while the tree scrolls")
  assert_eq(overlay_pos_after[2], overlay_pos[2], "search overlay column should remain fixed while the tree scrolls")

  assert_eq(explorer_win.measure_lines({ "ascii", "界.lua" }), 24, "minimum width should be respected")
  assert_eq(
    explorer_win.measure_lines({ string.rep("x", 100) }),
    math.min(72, vim.o.columns - 20),
    "configured and screen maximum widths should be respected"
  )
  explorer_win.fit_to_content({ string.rep("x", 48) }, { shrink = true })
  assert_eq(
    vim.api.nvim_win_get_config(S.search_win).width,
    vim.api.nvim_win_get_width(S.win),
    "fit-to-content should resize the complete explorer surface"
  )

  search.activate()
  assert_eq(vim.api.nvim_get_current_win(), S.search_win, "search input should focus the fixed overlay")
  local width_before_long_query = vim.api.nvim_win_get_width(S.win)
  local long_query = string.rep("界", 80)
  vim.api.nvim_buf_set_lines(
    S.search_buf,
    search_ui.INPUT_ROW,
    search_ui.INPUT_ROW + 1,
    false,
    { search_ui.line_text(long_query) }
  )
  search_ui.paint()
  assert_eq(
    vim.api.nvim_win_get_width(S.win),
    width_before_long_query,
    "long search input must not expand the explorer"
  )
  vim.api.nvim_buf_set_lines(
    S.search_buf,
    search_ui.INPUT_ROW,
    search_ui.INPUT_ROW + 1,
    false,
    { search_ui.line_text("") }
  )

  wait_for("search should render its result list while active", function()
    local lines = vim.api.nvim_buf_get_lines(S.buf, 0, -1, false)
    return S.search_active
      and #lines > search_ui.HEADER_LINES
      and lines[search_ui.HEADER_LINES + 1] ~= nil
      and lines[search_ui.HEADER_LINES + 1] ~= ""
  end)

  search.clear()
  vim.api.nvim_set_current_win(S.win)

  wait_for("search should exit cleanly before move flow starts", function()
    return not S.search_active and vim.api.nvim_get_current_win() == S.win
  end)
  vim.cmd("doautocmd ColorScheme")
  assert_ok(
    vim.wo[S.win].winhighlight:find("Normal:ExplorerNormal", 1, true)
      and vim.wo[S.search_win].winhighlight:find("Normal:ExplorerNormal", 1, true),
    "colorscheme refresh should preserve the shared explorer surface"
  )

  vim.api.nvim_win_set_cursor(S.win, { search_ui.line_for_item(1), 0 })
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

  vim.api.nvim_win_set_cursor(S.win, { search_ui.line_for_item(1), 0 })
  vim.cmd("normal! j")

  wait_for("explorer navigation should work after the move picker closes", function()
    return vim.api.nvim_win_get_cursor(S.win)[1] == search_ui.line_for_item(2)
  end)

  local empty_root = path("empty")
  vim.fn.mkdir(empty_root, "p")
  explorer.open({ root = empty_root })
  wait_for("empty directories should render a purposeful state", function()
    local line = vim.api.nvim_buf_get_lines(S.buf, search_ui.HEADER_LINES, search_ui.HEADER_LINES + 1, false)[1]
    return #S.items == 0 and line and line:find("Empty folder", 1, true) ~= nil
  end)
  assert_eq(vim.wo[S.win].cursorline, false, "empty state should not look like a selectable file row")
  explorer.open({ root = root })
  wait_for("tree should recover after leaving an empty directory", function()
    return #S.items >= 4
  end)

  local persistent_search_buf = S.search_buf
  vim.cmd("stopinsert")
  vim.api.nvim_set_current_win(S.search_win)
  explorer.close()
  wait_for("closing from the header should close the complete explorer", function()
    return not S.win and not S.search_win
  end)
  wait_for("closing should not orphan a visible search window", function()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == persistent_search_buf then
        return false
      end
    end
    return true
  end)
  assert_ok(
    persistent_search_buf and vim.api.nvim_buf_is_valid(persistent_search_buf),
    "normal close should retain one reusable search buffer"
  )

  explorer.open({ root = root })
  wait_for("explorer should reopen all managed regions", function()
    return S.win
      and vim.api.nvim_win_is_valid(S.win)
      and S.search_win
      and vim.api.nvim_win_is_valid(S.search_win)
  end)
  assert_eq(S.search_buf, persistent_search_buf, "reopen should reuse rather than leak search buffers")
  explorer.close()
  wait_for("closing from the tree API should close all explorer regions", function()
    return not S.win and not S.search_win
  end)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    assert_ok(
      not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= persistent_search_buf,
      "tree close should not leave a hidden or non-focusable header window"
    )
  end
end

local success, err = xpcall(run, debug.traceback)
cleanup()
if not success then
  error(err)
end
