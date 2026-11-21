-- =============================================================================
-- lua/overseer/template/python.lua
-- Python project runner provider for Overseer.
-- Only yields Python run/test/lint templates when inside a Python project.
-- =============================================================================

local detector = require("overseer_templates.detector")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts, cb)
    local is_match, _ = detector.is_python(opts)
    if not is_match then
      return "Not a Python project"
    end

    local tmpls = require("overseer_templates.python.init").get_templates()
    if cb then
      cb(tmpls)
    else
      return tmpls
    end
  end,
}
