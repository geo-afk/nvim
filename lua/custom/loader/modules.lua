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
---@param spec LoaderSpec
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

  for _, key_spec in ipairs(spec.keys) do
    if type(key_spec) == "table" and (key_spec.group or key_spec.icon or key_spec.desc) then
      local wk_spec = vim.deepcopy(key_spec)
      wk_spec[2] = nil
      state.which_key_specs[#state.which_key_specs + 1] = wk_spec
    end
  end

  utils.log("debug", "Registered: %s [%s]", spec.mod, spec.priority)
end

-- ── State accessors ───────────────────────────────────────────────────────────

---@param mod string
---@return LoaderSpec|nil
function M.get(mod)
  return state.registry[mod]
end

---@param mod string
---@return string
function M.get_state(mod)
  return state.load_state[mod] or "unregistered"
end

---@param mod string
---@param s string
function M.set_state(mod, s)
  state.load_state[mod] = s
  if s == M.S.LOADED then
    if not vim.tbl_contains(state.load_order, mod) then
      state.load_order[#state.load_order + 1] = mod
    end
  end
end

---@param mod string
---@return boolean
function M.is_loaded(mod)
  return state.load_state[mod] == M.S.LOADED
end

---@param mod string
---@return boolean
function M.is_loading(mod)
  return state.load_state[mod] == M.S.LOADING
end

---@param mod string
---@return boolean
function M.is_failed(mod)
  return state.load_state[mod] == M.S.FAILED
end

---@return table<string, LoaderSpec>
function M.get_all()
  return state.registry
end

function M.get_load_order()
  return state.load_order
end

function M.get_which_key_specs()
  return vim.deepcopy(state.which_key_specs)
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
