-- =============================================================================
-- lua/overseer/template/angular/init.lua
-- Auto-discovery entry-point for all Angular overseer templates.
-- =============================================================================
return {
  generator = function(_opts, cb)
    local templates = {}
    local modules = {
      "overseer.template.angular.serve",
      "overseer.template.angular.build",
      "overseer.template.angular.test",
      "overseer.template.angular.lint",
    }
    for _, mod in ipairs(modules) do
      local ok, m = pcall(require, mod)
      if ok then
        if type(m) == "table" and m.name then
          table.insert(templates, m)
        elseif type(m) == "table" then
          for _, t in ipairs(m) do table.insert(templates, t) end
        end
      end
    end
    cb(templates)
  end,
}
