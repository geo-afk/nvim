-- =============================================================================
-- lua/overseer/template/node/init.lua
-- Auto-discovery entry-point for all Node / TypeScript overseer templates.
-- =============================================================================
return {
  generator = function(_opts, cb)
    local templates = {}
    local modules = {
      "overseer.template.node.npm_scripts",
      "overseer.template.node.pnpm_scripts",
      "overseer.template.node.tsc",
      "overseer.template.node.eslint",
      "overseer.template.node.prettier",
      "overseer.template.node.vitest",
      "overseer.template.node.jest",
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
