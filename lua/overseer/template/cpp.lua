-- =============================================================================
-- lua/overseer/template/cpp.lua
-- C / C++ project runner provider for Overseer.
-- Only yields C/C++ build/run/make templates when inside a C/C++ project.
-- =============================================================================

local detector = require("overseer_templates.detector")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts, cb)
    local is_match, _ = detector.is_cpp(opts)
    if not is_match then
      return "Not a C/C++ project"
    end

    local tmpls = require("overseer_templates.cpp.init").get_templates(opts)
    if cb then
      cb(tmpls)
    else
      return tmpls
    end
  end,
}
