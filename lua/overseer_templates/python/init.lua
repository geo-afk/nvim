-- =============================================================================
-- lua/overseer_templates/python/init.lua
-- Python overseer templates loader
-- =============================================================================

return {
  get_templates = function()
    local templates = {}
    local modules = {
      "overseer_templates.python.run",
      "overseer_templates.python.test",
      "overseer_templates.python.lint",
    }
    for _, mod in ipairs(modules) do
      local ok, m = pcall(require, mod)
      if ok and type(m) == "table" then
        if m.name then
          table.insert(templates, m)
        else
          for _, t in ipairs(m) do
            table.insert(templates, t)
          end
        end
      end
    end
    return templates
  end,
}
