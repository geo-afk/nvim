-- =============================================================================
-- lua/overseer/template/node/pnpm_scripts.lua
-- Dynamic picker: reads package.json scripts and runs them via pnpm.
-- Supports monorepos: finds the nearest package.json with a "name" field.
-- =============================================================================

---@param start_dir string
---@return string|nil root, table|nil scripts, string|nil pkg_name
local function find_package(start_dir)
  -- Walk every ancestor and collect ALL package.json locations
  local current = start_dir
  local results  = {}
  for dir in vim.fs.parents(current) do
    local pkg_file = dir .. "/package.json"
    if vim.fn.filereadable(pkg_file) == 1 then
      local ok, content = pcall(vim.fn.readfile, pkg_file)
      if ok and content then
        local json_ok, pkg = pcall(vim.fn.json_decode, table.concat(content, "\n"))
        if json_ok and type(pkg) == "table" and type(pkg.scripts) == "table" then
          table.insert(results, { root = dir, scripts = pkg.scripts, name = pkg.name })
        end
      end
    end
    -- Stop at filesystem root / pnpm workspace root
    if vim.fn.filereadable(dir .. "/pnpm-workspace.yaml") == 1 then break end
  end
  if #results == 0 then return nil, nil, nil end
  -- Prefer the nearest (first) match
  local best = results[1]
  return best.root, best.scripts, best.name
end

return {
  generator = function(_opts, cb)
    if vim.fn.executable("pnpm") ~= 1 then cb({}) return end

    local cwd = vim.fn.expand("%:p:h")
    local root, scripts, pkg_name = find_package(cwd)
    if not root or not scripts then cb({}) return end

    local label_prefix = pkg_name and ("pnpm[" .. pkg_name .. "]: ") or "pnpm: "

    local templates = {}
    for script_name, script_cmd in pairs(scripts) do
      table.insert(templates, {
        name    = label_prefix .. script_name,
        builder = function(_params)
          return {
            name = "pnpm run " .. script_name,
            cmd  = { "pnpm", "run", script_name },
            cwd  = root,
            components = {
              "on_exit_set_status",
              { "on_complete_notify", system = "unfocused" },
              "on_complete_dispose",
            },
            metadata = {
              tags        = { "node", "pnpm", script_name },
              description = script_cmd,
            },
          }
        end,
        params   = {},
        priority = 61,
        tags     = { "node", "pnpm" },
        desc     = script_cmd,
      })
    end
    cb(templates)
  end,
}
