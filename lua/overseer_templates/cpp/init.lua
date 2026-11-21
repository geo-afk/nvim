-- =============================================================================
-- lua/overseer_templates/cpp/init.lua
-- C / C++ overseer templates loader
-- =============================================================================

local detector = require("overseer_templates.detector")

return {
  get_templates = function(opts)
    local dir = detector.get_dir(opts)
    local templates = {}

    local function add(m)
      if type(m) ~= "table" then return end
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

    local ok1, build_mod = pcall(require, "overseer_templates.cpp.build")
    if ok1 then add(build_mod) end

    local ok2, run_mod = pcall(require, "overseer_templates.cpp.run")
    if ok2 then add(run_mod) end

    local has_makefile = vim.fs.root(dir, { "Makefile", "makefile", "GNUmakefile" }) ~= nil
    local has_make = vim.fn.executable("mingw32-make") == 1 or vim.fn.executable("make") == 1
    if has_makefile and has_make then
      local ok3, make_mod = pcall(require, "overseer_templates.cpp.make")
      if ok3 then add(make_mod) end
    end

    return templates
  end,
}
