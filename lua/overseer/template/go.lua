-- =============================================================================
-- lua/overseer/template/go.lua
-- Go project runner provider for Overseer.
-- Only yields Go run/build/test templates when inside a Go project.
-- =============================================================================

local detector = require("overseer_templates.detector")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts, cb)
    local is_match, _ = detector.is_go(opts)
    if not is_match then
      return "Not a Go project"
    end

    local tmpls = require("overseer_templates.go.init").get_templates(opts)
    if cb then
      cb(tmpls)
    else
      return tmpls
    end
  end,
}
