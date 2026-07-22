local function assert_ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local loader = require("custom.loader")
loader.setup({ profile = false, debug = false, max_retries = 1 })

local configured = 0
package.preload["test_loader.base"] = function()
  return { value = 42 }
end
package.preload["test_loader.child"] = function()
  return { loaded = true }
end

loader.register({
  { mod = "test_loader.base" },
  {
    mod = "test_loader.child",
    deps = { "test_loader.base" },
    config = function(mod)
      assert_ok(mod.loaded, "config callback should receive module export")
      configured = configured + 1
    end,
  },
})

assert_ok(loader.load("test_loader.child"), "dependency load should succeed")
assert_ok(loader.is_loaded("test_loader.base"), "dependency should load first")
assert_ok(loader.is_loaded("test_loader.child"), "child should load")
assert_ok(configured == 1, "config callback should run exactly once")
assert_ok(loader.load("test_loader.child"), "cached load should succeed")
assert_ok(configured == 1, "cached load must not repeat config callback")

loader.register({
  { mod = "test_loader.cycle_a", deps = { "test_loader.cycle_b" } },
  { mod = "test_loader.cycle_b", deps = { "test_loader.cycle_a" } },
})
assert_ok(not loader.load("test_loader.cycle_a"), "dependency cycle must fail")

print("Loader tests passed!")
