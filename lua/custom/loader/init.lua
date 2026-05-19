-- lua/custom/loader/init.lua
-- Public API for the custom lazy-loading system.
--
-- Typical usage in your top-level init.lua:
--
--   local loader = require("custom.loader")
--
--   loader.setup({ profile = true, debug = false })
--
--   loader.register({
--     { mod = "custom.settings",        priority = "critical" },
--     { mod = "custom.keymaps",         priority = "critical" },
--     { mod = "custom.ui.statusline",   defer = true,  deps = { "custom.settings" } },
--     { mod = "custom.tools.git",       defer = true  },
--     { mod = "custom.lsp",             event = "LspAttach"  },
--     { mod = "custom.lang.python",     ft    = "python"     },
--     { mod = "custom.finder",          keys  = "<leader>f"  },
--     { mod = "custom.debug",           cmd   = "DebugStart" },
--     { mod = "custom.remote",
--       cond = function() return vim.fn.executable("ssh") == 1 end,
--       idle = true },
--   })
--
--   loader.bootstrap()   -- call once; schedules everything
--
-- After setup, you can query state at runtime:
--   loader.is_loaded("custom.lsp")        → bool
--   loader.state("custom.lsp")            → "loaded" | "registered" | …
--   loader.load("custom.lsp")             → bool (on-demand)
--   loader.reload("custom.lsp")           → bool (force-reload)

local M = {}

-- Sub-modules are required inside functions, not at module scope, so that
-- the loader itself doesn't block Neovim startup with heavyweight requires.
-- Once setup() is called the modules are all cached; subsequent calls are free.

-- ── setup ─────────────────────────────────────────────────────────────────────

---@param opts? { debug?: boolean, profile?: boolean, defer_timeout?: number, idle_batch?: number }
function M.setup(opts)
  local state = require("custom.loader.state")
  if state.initialized then
    return
  end

  if opts then
    for k, v in pairs(opts) do
      state.config[k] = v
    end
  end

  -- Enable Neovim's built-in bytecode cache (Neovim 0.9+, LuaJIT).
  -- This is the single highest-impact startup optimisation available.
  if vim.loader and not vim.g.loader_bytecache_enabled then
    vim.loader.enable()
    vim.g.loader_bytecache_enabled = true
  end

  -- Register debug UI commands.
  require("custom.loader.ui").setup()

  state.initialized = true
  require("custom.loader.utils").log(
    "debug",
    "initialised (profile=%s debug=%s)",
    tostring(state.config.profile),
    tostring(state.config.debug)
  )
end

-- ── register ──────────────────────────────────────────────────────────────────

--- Register one or a list of module specs.
--- Accepts: a single spec table  OR  a list of spec tables.
function M.register(specs)
  if not require("custom.loader.state").initialized then
    M.setup()
  end

  local modules = require("custom.loader.modules")
  local deps_mod = require("custom.loader.dependencies")

  -- Normalise: wrap single spec in a list.
  if type(specs) == "table" and type(specs.mod) == "string" then
    specs = { specs }
  end
  assert(type(specs) == "table", "register() expects a spec table or a list of spec tables")

  for _, spec in ipairs(specs) do
    if type(spec.mod) ~= "string" then
      require("custom.loader.utils").log("warn", "spec missing mod key, skipped")
    else
      -- Record dependency edges before registering the spec.
      local dep_list = require("custom.loader.utils").to_list(spec.deps)
      if #dep_list > 0 then
        deps_mod.register(spec.mod, dep_list)
      end
      modules.register(spec)
    end
  end
end

-- ── bootstrap ─────────────────────────────────────────────────────────────────

--- Schedule all registered modules according to their loading strategy.
--- Call exactly once, after all register() calls.
function M.bootstrap()
  if not require("custom.loader.state").initialized then
    M.setup()
  end

  local modules = require("custom.loader.modules")
  local core = require("custom.loader.core")
  local scheduler = require("custom.loader.scheduler")
  local utils = require("custom.loader.utils")

  local critical = {}
  local deferred = {}
  local idle = {}

  for mod, spec in pairs(modules.get_all()) do
    if modules.is_loaded(mod) then
      goto continue
    end

    local has_trigger = #spec.event > 0 or #spec.ft > 0 or #spec.cmd > 0 or #spec.keys > 0

    if has_trigger then
      -- Wire autocmd / command / keymap triggers.
      M._wire_triggers(spec)
    elseif spec.idle then
      idle[#idle + 1] = mod
    elseif spec.defer or spec.priority ~= "critical" then
      -- Default: defer non-critical modules so they don't block startup.
      deferred[#deferred + 1] = mod
    else
      -- priority == "critical": load synchronously during bootstrap.
      critical[#critical + 1] = mod
    end

    ::continue::
  end

  -- 1. Critical — load right now (synchronous, dependency-ordered).
  if #critical > 0 then
    core.load_batch(critical, { trigger = "critical" })
  end

  -- 2. Deferred — arm after VimEnter.
  if #deferred > 0 or #idle > 0 then
    local function on_vimenter()
      if #deferred > 0 then
        scheduler.schedule_deferred(function()
          core.load_batch(deferred, { trigger = "deferred" })
        end)
        scheduler.flush_deferred()
        -- Idle setup is triggered inside flush_deferred → process_deferred.
      end
      -- If there are only idle items (no deferred), set them up directly.
      if #idle > 0 then
        for _, mod in ipairs(idle) do
          local m = mod -- upvalue capture
          scheduler.schedule_idle(function()
            core.load(m, { trigger = "idle" })
          end)
        end
        if #deferred == 0 then
          scheduler._setup_idle_loader()
        end
      end
    end

    if vim.v.vim_did_enter == 1 then
      on_vimenter()
    else
      local aug = vim.api.nvim_create_augroup("LoaderBootstrap", { clear = true })
      vim.api.nvim_create_autocmd("VimEnter", {
        group = aug,
        once = true,
        callback = on_vimenter,
      })
    end
  end

  utils.log("debug", "bootstrap: critical=%d deferred=%d idle=%d", #critical, #deferred, #idle)
end

-- ── _wire_triggers (internal) ─────────────────────────────────────────────────

--- Wire autocmd, command, and keymap triggers for `spec`.
function M._wire_triggers(spec)
  local mod = spec.mod
  local events = require("custom.loader.events")
  local core = require("custom.loader.core")

  -- Event triggers.
  if #spec.event > 0 then
    events.on_event(spec.event, { mod })
  end

  -- Filetype triggers.
  if #spec.ft > 0 then
    events.on_filetype(spec.ft, { mod })
  end

  -- Command stubs: thin shims that load the real module on first call.
  for _, cmd in ipairs(spec.cmd) do
    if vim.fn.exists(":" .. cmd) ~= 2 then
      vim.api.nvim_create_user_command(cmd, function(cmd_opts)
        vim.api.nvim_del_user_command(cmd)
        core.load(mod, { trigger = "cmd:" .. cmd })
        -- Re-execute if the real command was registered by the module.
        if vim.fn.exists(":" .. cmd) == 2 then
          local bang = cmd_opts.bang and "!" or ""
          local args = cmd_opts.args ~= "" and (" " .. cmd_opts.args) or ""
          vim.cmd(cmd .. bang .. args)
        end
      end, { bang = true, nargs = "*", desc = "󱐌 " .. mod })
    end
  end

  -- Keymap stubs: feed the real key after loading so the bound action executes.
  for _, key_spec in ipairs(spec.keys) do
    local lhs = type(key_spec) == "table" and key_spec[1] or key_spec
    local mode = type(key_spec) == "table" and (key_spec.mode or "n") or "n"
    local user_desc = type(key_spec) == "table" and key_spec.desc

    local icon = "󱐌 "
    local label = user_desc or mod:match("[^.]+$")
    local final_desc = icon .. label

    vim.keymap.set(mode, lhs, function()
      vim.keymap.del(mode, lhs)
      core.load(mod, { trigger = "keys:" .. lhs })
      -- Re-feed the key so the real mapping (if any) fires.
      local key = vim.api.nvim_replace_termcodes(lhs, true, false, true)
      vim.api.nvim_feedkeys(key, "mt", false)
    end, { desc = final_desc, nowait = true })
  end
end

-- ── Public helpers ────────────────────────────────────────────────────────────

--- Directly load a module on demand (bypass triggers).
---@param mod   string
---@param opts? { force?: boolean }
---@return boolean ok
function M.load(mod, opts)
  return require("custom.loader.core").load(mod, opts)
end

--- Force-reload a module (invalidates Lua cache, re-requires).
---@param mod string
---@return boolean ok
function M.reload(mod)
  return require("custom.loader.core").reload(mod)
end

--- Current state of a module.
---@param mod string
---@return string  "loaded"|"registered"|"failed"|"skipped"|"unregistered"|…
function M.state(mod)
  return require("custom.loader.modules").get_state(mod)
end

---@param mod string
---@return boolean
function M.is_loaded(mod)
  return require("custom.loader.modules").is_loaded(mod)
end

return M
