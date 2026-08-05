local function fail(message)
  error(message, 2)
end

local function ok(value, message)
  if not value then
    fail(message or "assertion failed")
  end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    fail((message or "values differ") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
  end
end

local config_root = vim.fn.stdpath("config")
vim.opt.runtimepath:prepend(config_root)

-- Compile every repository Lua source without executing its side effects.
local lua_files = vim.fn.globpath(config_root, "**/*.lua", false, true)
local compiled = 0
for _, file in ipairs(lua_files) do
  local chunk, err = loadfile(file)
  ok(chunk ~= nil, ("Lua syntax error in %s: %s"):format(file, err or "unknown error"))
  compiled = compiled + 1
end
ok(compiled > 100, "repository discovery unexpectedly found too few Lua files")

local loader = require("custom.loader")
loader.setup({ profile = false, debug = false, max_retries = 0 })

local executions = {}
local function preload(name, factory)
  package.loaded[name] = nil
  package.preload[name] = function()
    executions[name] = (executions[name] or 0) + 1
    return factory()
  end
end

preload("audit_loader.value", function()
  return { answer = 42 }
end)
preload("audit_loader.nil_return", function()
  return nil
end)
preload("audit_loader.false_return", function()
  return false
end)
preload("audit_loader.runtime_error", function()
  error("injected runtime failure")
end)

local configured = 0
loader.register({
  { mod = "audit_loader.value", config = function(export) eq(export.answer, 42); configured = configured + 1 end },
  { mod = "audit_loader.nil_return" },
  { mod = "audit_loader.false_return" },
  { mod = "audit_loader.runtime_error" },
  { mod = "audit_loader.missing" },
})

ok(loader.load("audit_loader.value"), "ordinary module should load")
ok(loader.load("audit_loader.value"), "cached module should remain successful")
eq(executions["audit_loader.value"], 1, "ordinary module executed more than once")
eq(configured, 1, "configuration callback executed more than once")
ok(loader.load("audit_loader.nil_return"), "Lua-compatible nil-returning module should load")
eq(executions["audit_loader.nil_return"], 1, "nil-returning module executed more than once")
ok(loader.load("audit_loader.false_return"), "Lua-compatible false-returning module should load")
ok(loader.load("audit_loader.false_return"), "false-returning module should remain cached")
eq(executions["audit_loader.false_return"], 1, "false-returning module executed more than once")
ok(not loader.load("audit_loader.runtime_error"), "runtime error should be contained")
ok(not loader.load("audit_loader.missing"), "missing module should fail cleanly")

-- Duplicate specs must not replace the original registry entry or rerun setup.
loader.register({ mod = "audit_loader.value", config = function() configured = configured + 100 end })
ok(loader.load("audit_loader.value"))
eq(configured, 1, "duplicate registration changed an already registered module")

-- Invalid entries are skipped while valid neighbors remain usable.
local register_ok = pcall(loader.register, { { wrong = "shape" }, { mod = "audit_loader.invalid_neighbor" } })
ok(register_ok, "invalid list entry should not abort registration of neighboring specs")
package.preload["audit_loader.invalid_neighbor"] = function()
  return { usable = true }
end
ok(loader.load("audit_loader.invalid_neighbor"), "valid neighbor after malformed spec should load")

loader.register({
  { mod = "audit_loader.cycle_a", deps = { "audit_loader.cycle_b" } },
  { mod = "audit_loader.cycle_b", deps = { "audit_loader.cycle_a" } },
})
ok(not loader.load("audit_loader.cycle_a"), "dependency cycle should fail without recursion overflow")

print(("Audit architecture tests passed (%d Lua files compiled)"):format(compiled))
