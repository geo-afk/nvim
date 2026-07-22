-- tests/lightbulb_spec.lua
-- Unit tests for custom.lightbulb utility.

local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(
      (message or "values differ") .. string.format(": expected %s, got %s", vim.inspect(expected), vim.inspect(actual))
    )
  end
end

-- ── Mocks ────────────────────────────────────────────────────────────────────

local lightbulb = require("custom.lightbulb")

-- Save originals
local original_get_clients = vim.lsp.get_clients
local original_buf_request = vim.lsp.buf_request
local original_set_extmark = vim.api.nvim_buf_set_extmark
local original_get_cursor = vim.api.nvim_win_get_cursor
local original_get_buf = vim.api.nvim_get_current_buf
local original_buf_is_valid = vim.api.nvim_buf_is_valid

local mock_clients = {}
local mock_actions = {}
local extmark_calls = {}
local mock_cursor = { 1, 0 }

local test_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { "line 1", "line 2", "line 3", "line 4", "line 5" })
vim.api.nvim_win_set_buf(0, test_bufnr)
vim.bo[test_bufnr].filetype = "lua"
vim.bo[test_bufnr].buftype = ""
vim.bo[test_bufnr].buflisted = true

vim.lsp.get_clients = function() return mock_clients end
vim.lsp.buf_request = function(bufnr, method, params, callback)
  if method == "textDocument/codeAction" then
    callback(nil, mock_actions, { method = method, bufnr = bufnr })
  end
end
vim.api.nvim_buf_set_extmark = function(bufnr, ns, line, col, opts)
  table.insert(extmark_calls, { bufnr = bufnr, ns = ns, line = line, col = col, opts = opts })
end
vim.api.nvim_win_get_cursor = function() return mock_cursor end
vim.api.nvim_get_current_buf = function() return test_bufnr end
vim.api.nvim_buf_is_valid = function(b) 
  if b == test_bufnr then return true end
  return original_buf_is_valid(b)
end

-- ── Tests ────────────────────────────────────────────────────────────────────

local function reset()
  extmark_calls = {}
  mock_clients = {}
  mock_actions = {}
  mock_cursor = { 1, 0 }
end

print("Running lightbulb tests...")

-- Test 1: No actions found
reset()
mock_cursor = { 1, 0 }
mock_clients = { { id = 1, offset_encoding = "utf-16", supports_method = function(_, m) return m == "textDocument/codeAction" end } }
mock_actions = {}
lightbulb.refresh()
assert_eq(#extmark_calls, 0, "Should not show lightbulb when no actions found")

-- Test 2: Actions found
reset()
mock_cursor = { 2, 0 } -- change line
mock_clients = { { id = 1, offset_encoding = "utf-16", supports_method = function(_, m) return m == "textDocument/codeAction" end } }
mock_actions = { { title = "Fix it" } }
lightbulb.refresh()
assert_eq(#extmark_calls, 1, "Should show lightbulb when actions found")
assert_eq(extmark_calls[1].line, 1, "Should be on row 1 (0-indexed cursor row 2)")
assert_ok(extmark_calls[1].opts.sign_text ~= nil, "Should have sign text")

-- Test 3: Client doesn't support codeAction
reset()
mock_cursor = { 3, 0 } -- change line
mock_clients = { { id = 1, offset_encoding = "utf-16", supports_method = function() return false end } }
mock_actions = { { title = "Fix it" } }
lightbulb.refresh()
assert_eq(#extmark_calls, 0, "Should not show lightbulb when LSP doesn't support codeAction")

-- Test 4: Throttling (same line)
reset()
mock_cursor = { 4, 0 }
mock_clients = { { id = 1, offset_encoding = "utf-16", supports_method = function(_, m) return m == "textDocument/codeAction" end } }
mock_actions = { { title = "Fix it" } }
lightbulb.refresh() -- first call
assert_eq(#extmark_calls, 1, "Should show lightbulb on first call")
extmark_calls = {}
lightbulb.refresh() -- second call on same line
assert_eq(#extmark_calls, 0, "Should not re-request/re-render on same line")

-- ── Cleanup ──────────────────────────────────────────────────────────────────

vim.lsp.get_clients = original_get_clients
vim.lsp.buf_request = original_buf_request
vim.api.nvim_buf_set_extmark = original_set_extmark
vim.api.nvim_win_get_cursor = original_get_cursor
vim.api.nvim_get_current_buf = original_get_buf
vim.api.nvim_buf_is_valid = original_buf_is_valid

print("Lightbulb tests passed!")
