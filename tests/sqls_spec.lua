local function assert_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error((message or "values differ") .. string.format(": expected %s, got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local original_select = vim.ui.select
local original_input = vim.ui.input
local original_inputsecret = vim.fn.inputsecret

local function load_config(select_index, responses, secret_responses)
  local prompts = 0
  local response_index = 0
  local secret_index = 0

  vim.ui.select = function(items, _, callback)
    prompts = prompts + 1
    callback(select_index and items[select_index] or nil, select_index)
  end

  vim.ui.input = function(_, callback)
    response_index = response_index + 1
    callback(responses[response_index])
  end

  vim.fn.inputsecret = function()
    secret_index = secret_index + 1
    return secret_responses and secret_responses[secret_index] or nil
  end

  package.loaded["config.lsp.servers.sqls"] = nil
  return require("config.lsp.servers.sqls"), function()
    return prompts, secret_index
  end
end

local function resolve(config)
  local roots = 0
  config.root_dir(0, function()
    roots = roots + 1
  end)
  vim.wait(100, function()
    return roots > 0
  end)
  return roots
end

local function initialized_settings(config)
  local client_config = vim.deepcopy(config)
  client_config.before_init({}, client_config)
  return client_config.settings
end

local direct, direct_prompts = load_config(1, {}, {
  "host=db.internal port=5433 user=app password=secret dbname=accounts sslmode=require",
})
assert_eq(resolve(direct), 1, "direct connection should continue LSP startup")
assert_eq(initialized_settings(direct).sqls.connections, {
  {
    driver = "postgresql",
    dataSourceName = "host=db.internal port=5433 user=app password=secret dbname=accounts sslmode=require",
  },
}, "direct connection string should be passed to sqls")
assert_eq(direct_prompts(), 1, "connection mode should be requested once")

local fields = load_config(2, {
  "db.local",
  "5434",
  "reporter",
  "warehouse",
  "verify-full",
}, {
  " pa ss'word\\ ",
})
assert_eq(resolve(fields), 1, "field connection should continue LSP startup")
assert_eq(initialized_settings(fields).sqls.connections, {
  {
    driver = "postgresql",
    dataSourceName = "host='db.local' port='5434' user='reporter' password=' pa ss\\'word\\\\ ' dbname='warehouse' sslmode='verify-full'",
  },
}, "individual fields should produce a PostgreSQL data source name")

local plain, plain_prompts = load_config(3, {})
assert_eq(resolve(plain), 1, "plain sqls should continue LSP startup")
assert_eq(initialized_settings(plain).sqls.connections, nil, "plain sqls should omit connection settings")
assert_eq(resolve(plain), 1, "later SQL buffers should start without prompting again")
assert_eq(plain_prompts(), 1, "connection mode should only be requested for the first SQL buffer")

local empty = load_config(1, {}, { "   " })
assert_eq(resolve(empty), 1, "an empty connection should continue LSP startup")
assert_eq(initialized_settings(empty).sqls.connections, nil, "an empty connection should fall back to plain sqls")

local cancelled = load_config(nil, {})
assert_eq(resolve(cancelled), 1, "cancelling connection mode should continue LSP startup")
assert_eq(initialized_settings(cancelled).sqls.connections, nil, "cancelling connection mode should use plain sqls")

local queued_callback
local queued_prompts = 0
vim.ui.select = function(_, _, callback)
  queued_prompts = queued_prompts + 1
  queued_callback = callback
end
package.loaded["config.lsp.servers.sqls"] = nil
local queued = require("config.lsp.servers.sqls")
local released = { 0, 0 }
queued.root_dir(0, function()
  released[1] = released[1] + 1
end)
queued.root_dir(0, function()
  released[2] = released[2] + 1
end)
assert_eq(released, { 0, 0 }, "queued SQL buffers should wait for the connection choice")
assert_eq(queued_prompts, 1, "concurrent SQL buffers should share one prompt")
queued_callback(nil, nil)
assert_eq(released, { 1, 1 }, "all queued SQL buffers should resume after the connection choice")

vim.ui.select = original_select
vim.ui.input = original_input
vim.fn.inputsecret = original_inputsecret
