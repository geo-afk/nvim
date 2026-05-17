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

local angular = require("config.lsp.setup.angular")

local applied = {}
local original_apply_workspace_edit = vim.lsp.util.apply_workspace_edit

vim.lsp.util.apply_workspace_edit = function(edit, offset_encoding)
  applied[#applied + 1] = {
    edit = edit,
    offset_encoding = offset_encoding,
  }
end

local client = {
  name = "angularls",
  offset_encoding = "utf-16",
  server_capabilities = {},
  commands = {},
  exec_cmd = function()
    error("fallback exec_cmd should not run for Angular completion code actions")
  end,
}

local workspace_edit = {
  changes = {
    ["file:///C:/project/src/app/app.ts"] = {
      {
        range = {
          start = { line = 0, character = 0 },
          ["end"] = { line = 0, character = 0 },
        },
        newText = "import { TodoItemComponent } from './todo-item.component';\n",
      },
    },
  },
}

angular.setup(client)

assert_eq(client.server_capabilities.renameProvider, false, "angular rename should stay disabled")
assert_ok(
  type(client.commands["angular.applyCompletionCodeAction"]) == "function",
  "Angular completion code action command should be registered"
)

local callback_ran = false
client:exec_cmd({
  command = "angular.applyCompletionCodeAction",
  arguments = { { workspace_edit } },
}, { bufnr = 1 }, function()
  callback_ran = true
end)

vim.lsp.util.apply_workspace_edit = original_apply_workspace_edit

assert_eq(#applied, 1, "expected one workspace edit to be applied")
assert_eq(applied[1].edit, workspace_edit, "expected Angular workspace edit to pass through")
assert_eq(applied[1].offset_encoding, "utf-16", "expected client offset encoding")
assert_ok(callback_ran, "expected exec_cmd callback to run after applying Angular completion command")
