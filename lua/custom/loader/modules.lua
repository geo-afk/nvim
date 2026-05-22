-- lua/custom/loader/modules.lua
-- Module spec registry and state machine.
--
-- Each registered module moves through states:
--   registered → pending → loading → loaded
--                                  ↘ failed
--   registered → skipped  (condition false)
--
-- The registry is write-once per module name; duplicate registration is a no-op
-- with a debug warning so hot-reload paths don't silently stack specs.

local M = {}
local utils = require("custom.loader.utils")
local state = require("custom.loader.state")

-- ── State constants ───────────────────────────────────────────────────────────

M.S = {
  REGISTERED = "registered",
  PENDING = "pending",
  LOADING = "loading",
  LOADED = "loaded",
  FAILED = "failed",
  SKIPPED = "skipped",
}

-- ── Registration ──────────────────────────────────────────────────────────────

--- Register a module spec.
---
--- Required fields:
---   mod (string)  fully-qualified Lua module name
---
--- Optional fields:
---   priority  "critical"|"normal"|"low"   default "normal"
---   defer     bool    load after VimEnter
---   idle      bool    load during CursorHold idle time
---   event     string|string[]  autocmd events
---   ft        string|string[]  filetypes
---   cmd       string|string[]  user-command stubs
---   keys      string|{string, mode?}[]  keymap stubs
---   deps      string|string[]  module names that must load first
---   cond      bool|function    false → skip entirely
---   config    function(module) called after successful load
function M.register(spec)
  assert(type(spec) == "table", "spec must be a table")
  assert(type(spec.mod) == "string", "spec.mod must be a string")

  if state.registry[spec.mod] then
    utils.log("debug", "Already registered (skipped): %s", spec.mod)
    return
  end

  -- Normalise list fields.
  spec.deps = utils.to_list(spec.deps)
  spec.event = utils.to_list(spec.event)
  spec.ft = utils.to_list(spec.ft)
  spec.cmd = utils.to_list(spec.cmd)
  spec.keys = utils.to_list(spec.keys)

  spec.priority = spec.priority or "normal"

  state.registry[spec.mod] = spec
  state.load_state[spec.mod] = M.S.REGISTERED

  utils.log("debug", "Registered: %s [%s]", spec.mod, spec.priority)
end

-- ── State accessors ───────────────────────────────────────────────────────────

function M.get(mod)
  return state.registry[mod]
end

function M.get_state(mod)
  return state.load_state[mod] or "unregistered"
end

function M.set_state(mod, s)
  state.load_state[mod] = s
  if s == M.S.LOADED then
    if not vim.tbl_contains(state.load_order, mod) then
      state.load_order[#state.load_order + 1] = mod
    end
  end
end

function M.is_loaded(mod)
  return state.load_state[mod] == M.S.LOADED
end

function M.is_loading(mod)
  return state.load_state[mod] == M.S.LOADING
end

function M.is_failed(mod)
  return state.load_state[mod] == M.S.FAILED
end

function M.get_all()
  return state.registry
end

function M.get_load_order()
  return state.load_order
end

-- ── Load-order index ──────────────────────────────────────────────────────────

--- Return a map of mod -> ordinal (1-based) for fast lookups.
function M.load_order_index()
  local idx = {}
  for i, mod in ipairs(state.load_order) do
    idx[mod] = i
  end
  return idx
end

return M
