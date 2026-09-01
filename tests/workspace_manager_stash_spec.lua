-- Integration test: exercises the ACTUAL shipped stash/restore/terminate
-- code (not a standalone reproduction) against a real terminal job, because
-- this is the one guarantee the whole feature exists to make.
local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function pid_alive(pid)
  local f = io.open("/proc/" .. pid, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local actions = require("custom.workspace_manager.actions")
local state = require("custom.workspace_manager.state")

for i = #state.stack, 1, -1 do
  table.remove(state.stack, i)
end
state.next_id = 1

-- A real, long-running job — the exact "npm run dev" scenario from the README.
vim.cmd("split")
local win = vim.api.nvim_get_current_win()
local job_id = vim.fn.jobstart({ "sleep", "60" }, { term = true })
local buf = vim.api.nvim_get_current_buf()
vim.wait(150)
local pid = vim.fn.jobpid(job_id)
assert_ok(pid_alive(pid), "precondition: process should be alive right after jobstart")

-- Stash: window goes away, buffer + job must not.
local id = actions.stash({ win = win, notify = false })
assert_ok(id ~= nil, "stash() should succeed for a terminal window")
assert_ok(not vim.api.nvim_win_is_valid(win), "the original window should be gone after stash")
assert_ok(vim.api.nvim_buf_is_valid(buf), "the buffer must survive stash")
vim.wait(100)
assert_ok(pid_alive(pid), "the terminal job must still be running while stashed")
assert_ok(state.count() == 1, "the registry should have exactly one stashed item")

-- Restore: same buffer, same job, focused.
local restored = actions.restore({ id = id, notify = false })
assert_ok(restored, "restore() should succeed")
assert_ok(state.count() == 0, "the registry should be empty after restore")
assert_ok(vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()) == buf, "restore() should focus the original buffer")
assert_ok(vim.bo[buf].channel > 0, "restored buffer should keep its terminal channel")
assert_ok(pid_alive(pid), "the terminal job must still be running after restore")

-- Stash again, then terminate for real: this is the one path that SHOULD kill it.
local id2 = actions.stash({ win = vim.api.nvim_get_current_win(), notify = false })
assert_ok(id2 ~= nil, "second stash should succeed")
actions.terminate(id2)
vim.wait(300)
assert_ok(not pid_alive(pid), "terminate() should actually kill the process")
assert_ok(state.count() == 0, "terminate() should remove the item from the registry")

-- A modified, listed source buffer must never be swept up by the generic
-- catch-all provider's default (non-forced) stash path.
vim.cmd("new")
local src_buf = vim.api.nvim_get_current_buf()
local src_win = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, { "unsaved content" })
local before = state.count()
local blocked_id = actions.stash({ win = src_win, notify = false })
assert_ok(blocked_id == nil, "stashing a regular source window should be a no-op by default")
assert_ok(state.count() == before, "a blocked stash must not touch the registry")
assert_ok(vim.api.nvim_win_is_valid(src_win), "a blocked stash must not touch the window")

-- ...unless explicitly forced.
local forced_id = actions.stash({ win = src_win, notify = false, force = true })
assert_ok(forced_id ~= nil, "force = true should allow stashing a source window")
actions.remove(forced_id) -- don't bother restoring; just drop the registry entry

print("workspace_manager stash/restore/terminate integration tests passed!")
