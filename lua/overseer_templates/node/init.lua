-- =============================================================================
-- lua/overseer_templates/node/init.lua
-- Node / TypeScript overseer templates loader
-- =============================================================================

local detector = require("overseer_templates.detector")

return {
  get_templates = function(opts, cb)
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

    local has_tsconfig = vim.fs.root(dir, { "tsconfig.json" }) ~= nil
    if has_tsconfig and vim.fn.executable("tsc") == 1 then
      local ok, m = pcall(require, "overseer_templates.node.tsc")
      if ok then add(m) end
    end

    local static_modules = {
      "overseer_templates.node.eslint",
      "overseer_templates.node.prettier",
      "overseer_templates.node.vitest",
      "overseer_templates.node.jest",
    }
    for _, mod in ipairs(static_modules) do
      local ok, m = pcall(require, mod)
      if ok then add(m) end
    end

    local script_modules = {
      "overseer_templates.node.npm_scripts",
      "overseer_templates.node.pnpm_scripts",
    }
    local pending = #script_modules
    if pending == 0 then
      cb(templates)
      return
    end

    for _, mod in ipairs(script_modules) do
      local ok, m = pcall(require, mod)
      if ok and type(m) == "table" and m.generator then
        m.generator(opts, function(script_tmpls)
          if type(script_tmpls) == "table" then
            for _, t in ipairs(script_tmpls) do
              table.insert(templates, t)
            end
          end
          pending = pending - 1
          if pending == 0 then
            cb(templates)
          end
        end)
      else
        pending = pending - 1
        if pending == 0 then
          cb(templates)
        end
      end
    end
  end,
}
