-- =============================================================================
-- lua/overseer/template/go/init.lua
-- Auto-discovery entry-point for all Go overseer templates.
-- Overseer will `require("overseer.template.go")` and call :list() on it.
-- =============================================================================
return {
  generator = function(_opts, cb)
    -- Collect every sub-module in this directory and return their templates.
    local templates = {}
    local modules = {
      "overseer.template.go.build",
      "overseer.template.go.run",
      "overseer.template.go.test",
      "overseer.template.go.vet",
      "overseer.template.go.lint",
      "overseer.template.go.air",
      "overseer.template.go.templ",
      "overseer.template.go.sqlc",
    }
    for _, mod in ipairs(modules) do
      local ok, m = pcall(require, mod)
      if ok then
        if type(m) == "table" and m.name then
          -- Single template
          table.insert(templates, m)
        elseif type(m) == "table" then
          -- Module returned a list
          for _, t in ipairs(m) do
            table.insert(templates, t)
          end
        end
      end
    end
    cb(templates)
  end,
}
