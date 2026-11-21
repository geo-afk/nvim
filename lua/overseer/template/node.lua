-- =============================================================================
-- lua/overseer/template/node.lua
-- Node / TypeScript project runner provider for Overseer.
-- Only yields npm/pnpm/tsc/test templates when inside a Node/TS project.
-- =============================================================================

local detector = require("overseer_templates.detector")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts, cb)
    local is_match, _ = detector.is_node(opts)
    if not is_match then
      return "Not a Node project"
    end

    require("overseer_templates.node.init").get_templates(opts, cb)
  end,
}
