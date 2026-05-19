-- lua/dap/utils.lua
-- Shared helpers for all DAP adapter modules.

local M = {}

--- Walk ancestor directories to find the nearest directory containing `markers`.
---@param markers string|string[]
---@return string  absolute path of the root, or cwd if not found
function M.root(markers)
  if type(markers) == "string" then markers = { markers } end
  return vim.fs.root(vim.fn.expand("%:p:h"), markers)
    or vim.fn.getcwd()
end

--- Read and JSON-decode the nearest package.json.
---@return table|nil  decoded pkg table, or nil on failure
function M.read_package_json()
  local root = M.root({ "package.json" })
  local file = root .. "/package.json"
  if vim.fn.filereadable(file) == 0 then return nil end
  local raw = table.concat(vim.fn.readfile(file), "\n")
  local ok, pkg = pcall(vim.fn.json_decode, raw)
  return ok and type(pkg) == "table" and pkg or nil
end

--- Prompt for a port number, with a default fallback.
---@param prompt string
---@param default integer
---@return integer
function M.pick_port(prompt, default)
  local input = vim.fn.input(prompt .. " [" .. default .. "]: ")
  return tonumber(input) or default
end

--- Prompt for a process ID via dap.utils.pick_process (fuzzy list).
---@return integer
function M.pick_pid()
  return require("dap.utils").pick_process()
end

--- Build a sourceMapPathOverrides table for a given webRoot.
---@param web_root string
---@return table
function M.webpack_source_maps(web_root)
  return {
    ["webpack:///./src/*"] = web_root .. "/*",
    ["webpack:///src/*"]   = web_root .. "/*",
    ["webpack:///*"]       = "*",
    ["webpack:///./~/*"]   = web_root .. "/node_modules/*",
    ["./*"]                = web_root .. "/*",
  }
end

--- Resolve vscode-js-debug path (data dir or VSCODE_JS_DEBUG_PATH env var).
---@return string
function M.js_debug_path()
  local env = os.getenv("VSCODE_JS_DEBUG_PATH")
  if env and vim.fn.isdirectory(env) == 1 then return env end
  return vim.fn.stdpath("data") .. "/vscode-js-debug"
end

--- Return true when the file exists relative to cwd or as absolute path.
---@param path string
---@return boolean
function M.file_exists(path)
  if vim.fn.filereadable(path) == 1 then return true end
  local abs = vim.fn.getcwd() .. "/" .. path
  return vim.fn.filereadable(abs) == 1
end

--- Resolve binary from PATH; warn if missing.
---@param bin string
---@return string  the binary name (unchanged; let the OS resolve it)
function M.require_bin(bin)
  if vim.fn.executable(bin) ~= 1 then
    vim.notify(
      ("[dap] '%s' not found in PATH. Install it and retry."):format(bin),
      vim.log.levels.WARN
    )
  end
  return bin
end

return M
