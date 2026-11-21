-- =============================================================================
-- lua/overseer_templates/angular/init.lua
-- Angular overseer templates loader
-- =============================================================================

return {
  get_templates = function(_opts)
    local templates = {}
    local modules = {
      "overseer_templates.angular.serve",
      "overseer_templates.angular.build",
      "overseer_templates.angular.test",
      "overseer_templates.angular.lint",
    }
    for _, mod in ipairs(modules) do
      local ok, m = pcall(require, mod)
      if ok and type(m) == "table" then
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
    end
    return templates
  end,
}
