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

local KEYMAP_SPEC_KEYS = {
  buffer = true,
  desc = true,
  expr = true,
  nowait = true,
  remap = true,
  replace_keycodes = true,
  script = true,
  silent = true,
  unique = true,
}

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

    -- Evaluate condition early during bootstrap.
    local cond_ok = true
    if spec.cond ~= nil then
      if type(spec.cond) == "function" then
        local ok, res = pcall(spec.cond)
        cond_ok = ok and res == true
      else
        cond_ok = spec.cond == true
      end
    end

    if not cond_ok then
      modules.set_state(mod, modules.S.SKIPPED)
      utils.log("debug", "condition false during bootstrap, skipped: %s", mod)
      goto continue
    end

    local has_trigger = #spec.event > 0 or #spec.ft > 0 or #spec.cmd > 0 or #spec.keys > 0

    if has_trigger then
      -- Wire autocmd / command / keymap triggers.
      M._wire_triggers(spec)
    end

    if spec.priority == "critical" then
      -- Critical modules still load during bootstrap even when they expose
      -- command/key stubs for metadata or replay.
      critical[#critical + 1] = mod
    elseif has_trigger then
      -- Trigger-only modules load on demand.
    elseif spec.idle then
      idle[#idle + 1] = mod
    elseif spec.defer or spec.priority ~= "critical" then
      -- Default: defer non-critical modules so they don't block startup.
      deferred[#deferred + 1] = mod
    end

    ::continue::
  end

  -- 1. Critical — load right now (synchronous, dependency-ordered).
  if #critical > 0 then
    core.load_batch(critical, { trigger = "critical" })
  end

  table.sort(deferred, function(a, b)
    local ma = modules.get(a) or {}
    local mb = modules.get(b) or {}
    local rank = { high = 1, normal = 2, low = 3 }
    local pa = rank[ma.priority] or 2
    local pb = rank[mb.priority] or 2
    if pa ~= pb then
      return pa < pb
    end
    return a < b
  end)

  -- 2. Deferred — arm after VimEnter.
  if #deferred > 0 or #idle > 0 then
    local function on_vimenter()
      if #deferred > 0 then
        scheduler.schedule_deferred(function()
          core.load_batch(deferred, { trigger = "deferred", continue_on_error = true })
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

  local function command_replay(cmd_name, cmd_opts)
    local cmd_args = {
      cmd = cmd_name,
      args = cmd_opts.fargs or {},
      bang = cmd_opts.bang or false,
    }

    if cmd_opts.range and cmd_opts.range > 0 then
      cmd_args.range = { cmd_opts.line1, cmd_opts.line2 }
    end
    if cmd_opts.reg and cmd_opts.reg ~= "" then
      cmd_args.reg = cmd_opts.reg
    end
    if cmd_opts.mods and cmd_opts.mods ~= "" then
      cmd_args.mods = cmd_opts.mods
    end

    vim.api.nvim_cmd(cmd_args, {})
  end

  local function keymap_opts(key_spec)
    if type(key_spec) ~= "table" then
      return { desc = "Load " .. mod, nowait = true }
    end

    local opts = {}
    for k, v in pairs(key_spec) do
      if KEYMAP_SPEC_KEYS[k] then
        opts[k] = v
      end
    end
    opts.desc = opts.desc or ("Load " .. mod)
    if opts.nowait == nil then
      opts.nowait = true
    end
    return opts
  end

  local function del_keymap(mode, lhs, del_opts)
    for _, m in ipairs(require("custom.loader.utils").to_list(mode)) do
      pcall(vim.keymap.del, m, lhs, del_opts)
    end
  end

  local function replay_rhs(rhs)
    if type(rhs) == "function" then
      rhs()
      return
    end

    if type(rhs) ~= "string" then
      return
    end

    local keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)
    vim.api.nvim_feedkeys(keys, "mt", false)
  end

  -- Event triggers.
  if #spec.event > 0 then
    events.on_event(spec.event, { mod })
  end

  -- Filetype triggers.
  if #spec.ft > 0 then
    events.on_filetype(spec.ft, { mod })
  end

  -- Command and keymap stubs: only register globally if the module is NOT filetype-specific.
  if #spec.ft == 0 then
    -- Command stubs: thin shims that load the real module on first call.
    for _, cmd in ipairs(spec.cmd) do
      if vim.fn.exists(":" .. cmd) ~= 2 then
        local function create_command_stub()
          vim.api.nvim_create_user_command(cmd, function(cmd_opts)
            pcall(vim.api.nvim_del_user_command, cmd)

            local ok = core.load(mod, { trigger = "cmd:" .. cmd })
            if not ok then
              create_command_stub()
              return
            end

            -- Re-execute if the real command was registered by the module.
            if vim.fn.exists(":" .. cmd) == 2 then
              command_replay(cmd, cmd_opts)
            end
          end, { bang = true, nargs = "*", range = true, desc = "Load " .. mod })
        end

        create_command_stub()
      end
    end

    -- Keymap stubs: feed the real key after loading so the bound action executes.
    for _, key_spec in ipairs(spec.keys) do
      local lhs = type(key_spec) == "table" and key_spec[1] or key_spec
      local rhs = type(key_spec) == "table" and key_spec[2] or nil
      local mode = type(key_spec) == "table" and (key_spec.mode or "n") or "n"
      local opts = keymap_opts(key_spec)
      local del_opts = opts.buffer and { buffer = opts.buffer } or nil

      if not (type(key_spec) == "table" and key_spec.group and rhs == nil) then
        local function create_key_stub()
          vim.keymap.set(mode, lhs, function()
            del_keymap(mode, lhs, del_opts)

            local ok = core.load(mod, { trigger = "keys:" .. lhs })
            if not ok then
              create_key_stub()
              return
            end

            vim.schedule(function()
              if rhs ~= nil then
                replay_rhs(rhs)
                return
              end

              -- Re-feed the key so the real mapping (if any) fires.
              replay_rhs(lhs)
            end)
          end, opts)
        end

        create_key_stub()
      end
    end
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

function M.which_key_specs()
  return require("custom.loader.modules").get_which_key_specs()
end

return M
