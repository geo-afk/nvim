-- lua/custom/loader/state.lua
-- Single source of truth for all loader state.
-- Nothing else owns mutable data — all subsystems read/write here.
-- Kept as flat tables; no metatables, no indirection overhead.

local M = {}

M.config = {
  debug = false, -- verbose logging
  profile = false, -- enable load-time tracking
  defer_timeout = 100, -- ms after VimEnter before deferred flush
  idle_batch = 3, -- modules loaded per CursorHold tick
  max_retries = 1, -- reload attempts on failure
}

-- spec registry: mod_name (string) -> spec (table)
M.registry = {}

-- load state machine: mod_name -> "registered"|"pending"|"loading"|"loaded"|"failed"|"skipped"
M.load_state = {}

-- ordered list of successfully loaded mod names (append-only)
M.load_order = {}

-- autocmd IDs created by the event subsystem (for potential cleanup)
M.autocmd_ids = {}

-- which-key v3 metadata collected from module specs before which-key loads
M.which_key_specs = {}

-- guard: setup() called
M.initialized = false

return M
