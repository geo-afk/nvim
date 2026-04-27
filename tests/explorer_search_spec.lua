local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local ok_search, search = pcall(require, "custom.explorer.search")
if not ok_search then
  error(search)
end

local function run()
  local first = 4

  assert_eq(
    search._compute_result_topline(first, 12, first, 5, first + 2),
    first,
    "small flat result sets should stay pinned instead of jumping"
  )

  assert_eq(
    search._compute_result_topline(20, 12, first, 40, 21),
    19,
    "moving near the top edge should only scroll enough to restore padding"
  )

  assert_eq(
    search._compute_result_topline(20, 12, first, 40, 25),
    20,
    "moving inside the visible viewport should not change topline"
  )

  assert_eq(
    search._compute_result_topline(20, 12, first, 40, 31),
    22,
    "moving near the bottom edge should scroll minimally instead of jumping"
  )
end

local success, err = xpcall(run, debug.traceback)
if not success then
  error(err)
end
