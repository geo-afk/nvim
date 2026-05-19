-- lua/dap/node.lua
-- Node.js · TypeScript · JavaScript debug adapter (vscode-js-debug)
--
-- One-time setup:
--   git clone https://github.com/microsoft/vscode-js-debug $env:LOCALAPPDATA\nvim-data\vscode-js-debug
--   cd vscode-js-debug && npm install && npx gulp vsDebugServerBundle && mv dist out

local dap_ok, dap = pcall(require, "dap")
if not dap_ok then return end

local u = require("dap.local_utils")

-- ---------------------------------------------------------------------------
-- nvim-dap-vscode-js
-- ---------------------------------------------------------------------------
local vjs_ok, vjs = pcall(require, "dap-vscode-js")
if vjs_ok then
  vjs.setup({
    debugger_path  = u.js_debug_path(),
    adapters       = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
    log_file_path  = vim.fn.stdpath("cache") .. "/dap_vscode_js.log",
    log_file_level = false,
    log_console_level = vim.log.levels.ERROR,
  })
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function js_root()
  return u.root({ "package.json", "tsconfig.json", ".git" })
end

local function pick_npm_script()
  local pkg = u.read_package_json()
  if not pkg or type(pkg.scripts) ~= "table" then
    return vim.fn.input("npm script: ")
  end
  local names = vim.tbl_keys(pkg.scripts)
  table.sort(names)
  local items = vim.tbl_map(function(n) return n .. "  — " .. pkg.scripts[n] end, names)
  local choice = vim.fn.inputlist(vim.list_extend({ "npm scripts:" }, items))
  return names[choice] or names[1] or "start"
end

-- ---------------------------------------------------------------------------
-- Node configurations
-- ---------------------------------------------------------------------------
local node_cfgs = {
  {
    type    = "pwa-node",
    name    = "Node: Launch file",
    request = "launch",
    program = "${file}",
    cwd     = js_root,
    sourceMaps = true,
    resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
  },
  {
    type    = "pwa-node",
    name    = "Node: Launch with args",
    request = "launch",
    program = "${file}",
    cwd     = js_root,
    args    = function()
      return vim.split(vim.fn.input("Args: "), " ", { plain = true })
    end,
    sourceMaps = true,
  },
  {
    type    = "pwa-node",
    name    = "Node: npm run <script>",
    request = "launch",
    cwd     = js_root,
    runtimeExecutable = "npm",
    runtimeArgs = function() return { "run", pick_npm_script() } end,
    sourceMaps  = true,
    console     = "integratedTerminal",
  },
  {
    type    = "pwa-node",
    name    = "Node: Attach (port)",
    request = "attach",
    port    = function() return u.pick_port("Inspect port", 9229) end,
    cwd     = js_root,
    sourceMaps = true,
    restart    = true,
    skipFiles  = { "<node_internals>/**" },
  },
  {
    type      = "pwa-node",
    name      = "Node: Attach (PID)",
    request   = "attach",
    processId = u.pick_pid,
    cwd       = js_root,
    sourceMaps = true,
    skipFiles  = { "<node_internals>/**" },
  },
  {
    type    = "node-terminal",
    name    = "Node: Terminal launch",
    request = "launch",
    command = function() return vim.fn.input("Command: ", "node ") end,
    cwd     = js_root,
  },
}

-- ---------------------------------------------------------------------------
-- TypeScript configurations
-- ---------------------------------------------------------------------------
local ts_cfgs = {
  {
    type    = "pwa-node",
    name    = "TS: ts-node (file)",
    request = "launch",
    cwd     = js_root,
    runtimeExecutable = "node",
    runtimeArgs = { "--require", "ts-node/register", "--require", "tsconfig-paths/register" },
    program     = "${file}",
    sourceMaps  = true,
    resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
    env   = { TS_NODE_PROJECT = "${workspaceFolder}/tsconfig.json" },
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  },
  {
    type    = "pwa-node",
    name    = "TS: tsx (file)",
    request = "launch",
    cwd     = js_root,
    runtimeExecutable = "node",
    runtimeArgs = { "--import", "tsx/esm" },
    program     = "${file}",
    sourceMaps  = true,
    skipFiles   = { "<node_internals>/**", "**/node_modules/**" },
  },
  {
    type    = "pwa-node",
    name    = "TS: Attach (port)",
    request = "attach",
    port    = function() return u.pick_port("Inspect port", 9229) end,
    cwd     = js_root,
    sourceMaps = true,
    skipFiles  = { "<node_internals>/**" },
  },
  {
    type    = "pwa-node",
    name    = "TS: Debug vitest (all)",
    request = "launch",
    cwd     = js_root,
    program = function() return js_root() .. "/node_modules/.bin/vitest" end,
    args    = { "run", "--reporter=verbose" },
    sourceMaps = true,
    smartStep  = true,
    skipFiles  = { "<node_internals>/**", "**/node_modules/.pnpm/**" },
    console    = "integratedTerminal",
  },
  {
    type    = "pwa-node",
    name    = "TS: Debug jest (all)",
    request = "launch",
    cwd     = js_root,
    program = function() return js_root() .. "/node_modules/.bin/jest" end,
    args    = { "--runInBand", "--watchAll=false" },
    sourceMaps = true,
    smartStep  = true,
    skipFiles  = { "<node_internals>/**" },
    console    = "integratedTerminal",
  },
}

-- ---------------------------------------------------------------------------
-- Browser configurations (Chrome / Edge)
-- ---------------------------------------------------------------------------
local browser_cfgs = {
  {
    type    = "pwa-chrome",
    name    = "Chrome: Launch (4200)",
    request = "launch",
    url     = "http://localhost:4200",
    webRoot  = function() return js_root() .. "/src" end,
    sourceMaps = true,
    sourceMapPathOverrides = u.webpack_source_maps("${webRoot}"),
  },
  {
    type    = "pwa-chrome",
    name    = "Chrome: Attach (9222)",
    request = "attach",
    port    = 9222,
    webRoot  = function() return js_root() .. "/src" end,
    sourceMaps = true,
  },
  {
    type    = "pwa-msedge",
    name    = "Edge: Launch (4200)",
    request = "launch",
    url     = "http://localhost:4200",
    webRoot  = function() return js_root() .. "/src" end,
    sourceMaps = true,
    sourceMapPathOverrides = u.webpack_source_maps("${webRoot}"),
  },
}

-- ---------------------------------------------------------------------------
-- Register
-- ---------------------------------------------------------------------------
local all = vim.list_extend(vim.list_extend({}, node_cfgs), ts_cfgs)

for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
  dap.configurations[ft] = dap.configurations[ft] or {}
  vim.list_extend(dap.configurations[ft], all)
  vim.list_extend(dap.configurations[ft], browser_cfgs)
end

for _, ft in ipairs({ "html" }) do
  dap.configurations[ft] = dap.configurations[ft] or {}
  vim.list_extend(dap.configurations[ft], browser_cfgs)
end
