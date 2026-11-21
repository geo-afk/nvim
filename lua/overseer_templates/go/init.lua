-- =============================================================================
-- lua/overseer_templates/go/init.lua
-- Go overseer templates loader
-- =============================================================================

local detector = require("overseer_templates.detector")

return {
  get_templates = function(opts)
    local dir = detector.get_dir(opts)
    local templates = {}

    local function add(m)
      if type(m) ~= "table" then return end
      if m.name then
        local t = vim.deepcopy(m)
        t.condition = nil
        table.insert(templates, t)
      else
        for _, sub in ipairs(m) do
          if type(sub) == "table" and sub.name then
            local t = vim.deepcopy(sub)
            t.condition = nil
            table.insert(templates, t)
          end
        end
      end
    end

    -- Core Go tasks (always available in Go projects)
    local core = {
      "overseer_templates.go.run",
      "overseer_templates.go.build",
      "overseer_templates.go.test",
      "overseer_templates.go.vet",
    }
    for _, mod in ipairs(core) do
      local ok, m = pcall(require, mod)
      if ok then add(m) end
    end

    -- golangci-lint (only if executable)
    if vim.fn.executable("golangci-lint") == 1 then
      local ok, m = pcall(require, "overseer_templates.go.lint")
      if ok then add(m) end
    end

    -- air (live-reload, only if executable)
    if vim.fn.executable("air") == 1 then
      local ok, m = pcall(require, "overseer_templates.go.air")
      if ok then add(m) end
    end

    -- templ (only if executable or .templ files exist)
    local has_templ_files = #vim.fs.find(function(name)
      return name:match("%.templ$")
    end, { path = dir, limit = 1, type = "file" }) > 0
    if vim.fn.executable("templ") == 1 and has_templ_files then
      local ok, m = pcall(require, "overseer_templates.go.templ")
      if ok then add(m) end
    end

    -- sqlc (only if executable and sqlc config exists)
    local has_sqlc_cfg = vim.fs.root(dir, { "sqlc.yaml", "sqlc.yml" }) ~= nil
    if vim.fn.executable("sqlc") == 1 and has_sqlc_cfg then
      local ok, m = pcall(require, "overseer_templates.go.sqlc")
      if ok then add(m) end
    end

    return templates
  end,
}
