-- lua/dap/angular.lua
-- Angular debug configurations:
--   A) Chrome / Edge browser  (ng serve running on :4200)
--   B) Karma test runner      (ng test --browsers=ChromeHeadlessDebug)
--   C) Node / SSR             (Angular Universal)

local dap_ok, dap = pcall(require, "dap")
if not dap_ok then return end

local u = require("dap.local_utils")

local function ng_root()
  return u.root({ "angular.json", "package.json" })
end

local function ng_webroot()
  return ng_root() .. "/src"
end

-- ---------------------------------------------------------------------------
-- A. Browser
-- ---------------------------------------------------------------------------
local browser_cfgs = {
  {
    type    = "pwa-chrome",
    name    = "Angular: Debug in Chrome",
    request = "launch",
    url     = function()
      return vim.fn.input("URL [http://localhost:4200]: ", "http://localhost:4200")
    end,
    webRoot    = ng_webroot,
    sourceMaps = true,
    sourceMapPathOverrides = u.webpack_source_maps("${webRoot}"),
    runtimeArgs = { "--disable-extensions" },
  },
  {
    type      = "pwa-chrome",
    name      = "Angular: Attach Chrome (9222)",
    request   = "attach",
    port      = 9222,
    webRoot    = ng_webroot,
    sourceMaps = true,
    sourceMapPathOverrides = u.webpack_source_maps("${webRoot}"),
    urlFilter  = "http://localhost:4200/*",
  },
  {
    type    = "pwa-msedge",
    name    = "Angular: Debug in Edge",
    request = "launch",
    url     = function()
      return vim.fn.input("URL [http://localhost:4200]: ", "http://localhost:4200")
    end,
    webRoot    = ng_webroot,
    sourceMaps = true,
    sourceMapPathOverrides = u.webpack_source_maps("${webRoot}"),
  },
}

-- ---------------------------------------------------------------------------
-- B. Karma
-- ---------------------------------------------------------------------------
-- karma.conf.js must have:
--   customLaunchers: { ChromeHeadlessDebug: { base: "ChromeHeadless",
--     flags: ["--remote-debugging-port=9333"] } }
-- Run: ng test --browsers=ChromeHeadlessDebug
local karma_cfgs = {
  {
    type       = "pwa-chrome",
    name       = "Angular: Karma (9333)",
    request    = "attach",
    port       = 9333,
    webRoot     = ng_root,
    sourceMaps  = true,
    sourceMapPathOverrides = {
      ["webpack:///./src/*"]  = ng_webroot() .. "/*",
      ["webpack:///src/*"]    = ng_webroot() .. "/*",
      ["webpack:///*"]        = "*",
    },
    stopOnEntry = false,
  },
}

-- ---------------------------------------------------------------------------
-- C. SSR / Universal
-- ---------------------------------------------------------------------------
local ssr_cfgs = {
  {
    type    = "pwa-node",
    name    = "Angular: SSR launch",
    request = "launch",
    program = function()
      local dist = ng_root() .. "/dist/server/main.js"
      if vim.fn.filereadable(dist) == 1 then return dist end
      return vim.fn.input("SSR entry: ", ng_root() .. "/")
    end,
    cwd       = ng_root,
    sourceMaps = true,
    skipFiles  = { "<node_internals>/**", "**/node_modules/**" },
    env        = { NODE_ENV = "development" },
  },
  {
    type    = "pwa-node",
    name    = "Angular: SSR attach",
    request = "attach",
    port    = function() return u.pick_port("Inspect port", 9229) end,
    cwd     = ng_root,
    sourceMaps = true,
    skipFiles  = { "<node_internals>/**" },
  },
}

-- ---------------------------------------------------------------------------
-- Register
-- ---------------------------------------------------------------------------
local all = vim.list_extend(
  vim.list_extend({}, browser_cfgs),
  vim.list_extend(karma_cfgs, ssr_cfgs)
)

for _, ft in ipairs({ "typescript", "typescriptreact", "html", "javascript" }) do
  dap.configurations[ft] = dap.configurations[ft] or {}
  vim.list_extend(dap.configurations[ft], all)
end

-- ---------------------------------------------------------------------------
-- Angular-specific keymaps
-- ---------------------------------------------------------------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
end

map("<leader>das", function()
  -- Start ng serve via overseer if not already running, then attach Chrome
  local ov_ok, overseer = pcall(require, "overseer")
  local already_serving  = false

  if ov_ok then
    for _, task in ipairs(overseer.list_tasks()) do
      if task.status == "RUNNING"
        and task.metadata
        and vim.tbl_contains(task.metadata.tags or {}, "serve") then
        already_serving = true
        break
      end
    end
    if not already_serving then
      overseer.run_template({ name = "ng: serve" })
    end
  end

  local delay = already_serving and 0 or 5000
  vim.defer_fn(function()
    dap.run({
      type       = "pwa-chrome",
      name       = "Angular: Debug in Chrome",
      request    = "launch",
      url        = "http://localhost:4200",
      webRoot    = ng_webroot(),
      sourceMaps = true,
      sourceMapPathOverrides = u.webpack_source_maps(ng_webroot()),
    })
  end, delay)
end, "DAP Angular: Serve + Chrome debug")

map("<leader>dat", function()
  dap.run({
    type       = "pwa-chrome",
    name       = "Angular: Karma",
    request    = "attach",
    port       = 9333,
    webRoot    = ng_webroot(),
    sourceMaps = true,
  })
end, "DAP Angular: Attach Karma (9333)")
