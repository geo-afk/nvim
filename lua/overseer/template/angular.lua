-- =============================================================================
-- lua/overseer/template/angular.lua
-- Angular project runner provider for Overseer.
-- Only yields Angular serve/build/test/lint templates when inside an Angular project.
-- =============================================================================

local detector = require("overseer_templates.detector")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts, cb)
    local is_match, _ = detector.is_angular(opts)
    if not is_match then
      return "Not an Angular project"
    end

    local tmpls = require("overseer_templates.angular.init").get_templates()
    if cb then
      cb(tmpls)
    else
      return tmpls
    end
  end,
}
