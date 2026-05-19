-- =============================================================================
-- lua/overseer/template/node/npm_scripts.lua
-- Dynamic picker: reads package.json scripts and generates one task per script.
-- Supports monorepos / workspace roots by walking up from cwd.
-- =============================================================================

---@param start_dir string
---@return string|nil pkg_path, table|nil scripts
local function find_package_json(start_dir)
  local root = vim.fs.root(start_dir, { "package.json" })
  if not root then return nil, nil end
  local pkg_file = root .. "/package.json"
  local ok, content = pcall(vim.fn.readfile, pkg_file)
  if not ok or not content then return nil, nil end
  local json_ok, pkg = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not json_ok or type(pkg) ~= "table" then return nil, nil end
  return root, pkg.scripts or {}
end

return {
  generator = function(_opts, cb)
    local cwd = vim.fn.expand("%:p:h")
    local root, scripts = find_package_json(cwd)
    if not root or not scripts then cb({}) return end

    -- Check whether we should use npm (default)
    local use_npm = vim.fn.executable("npm") == 1

    local templates = {}
    for script_name, script_cmd in pairs(scripts) do
      table.insert(templates, {
        name    = "npm: " .. script_name,
        builder = function(_params)
          return {
            name = "npm run " .. script_name,
            cmd  = { "npm", "run", script_name },
            cwd  = root,
            components = {
              { "display_duration",   detail_level = 2 },
              "on_output_summarize",
              "on_exit_set_status",
              { "on_complete_notify", system = "unfocused" },
              "on_complete_dispose",
            },
            metadata = {
              tags        = { "node", "npm", script_name },
              description = script_cmd,
            },
          }
        end,
        params   = {},
        priority = 60,
        tags     = { "node", "npm" },
        desc     = script_cmd,
      })
    end
    cb(templates)
  end,
}
