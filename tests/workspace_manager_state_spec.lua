local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local state = require("custom.workspace_manager.state")

-- Defensive reset: this file runs standalone, but module tables persist for
-- the life of the process, so don't assume a virgin registry.
for i = #state.stack, 1, -1 do
  table.remove(state.stack, i)
end
state.next_id = 1

assert_ok(state.count() == 0, "registry should start empty")

local a = state.push({ provider = "generic", label = "A", meta = {} })
local b = state.push({ provider = "float_term", label = "B", meta = {} })
local c = state.push({ provider = "dap", label = "C", meta = {} })

assert_ok(state.count() == 3, "count should be 3 after three pushes")
assert_ok(a.id == 1 and b.id == 2 and c.id == 3, "ids should be monotonic")
assert_ok(type(a.stashed_at) == "number", "push() should stamp stashed_at")

-- MRU/LIFO ordering: list() is most-recent-first; pop() with no id pops the tail.
local listed = state.list()
assert_ok(
  listed[1].label == "C" and listed[2].label == "B" and listed[3].label == "A",
  "list() should be most-recent-first"
)

assert_ok(state.get(b.id).label == "B", "get() should find by id")
assert_ok(state.find_by_provider("dap").label == "C", "find_by_provider() should find the dap item")
assert_ok(state.find_by_provider("nope") == nil, "find_by_provider() should return nil for no match")

local popped = state.pop() -- no id => most recent (LIFO)
assert_ok(popped.label == "C", "pop() with no id should pop the most recent")
assert_ok(state.count() == 2, "count should drop after pop")

local popped_by_id = state.pop(a.id)
assert_ok(popped_by_id.label == "A", "pop(id) should remove that specific item, not just the tail")
assert_ok(state.count() == 1, "count should reflect the removal")
assert_ok(state.peek().label == "B", "the one remaining item should be B")

assert_ok(state.pop(999) == nil, "pop() with an unknown id should return nil")
assert_ok(state.count() == 1, "a failed pop should not change the count")

print("workspace_manager state tests passed!")
