-- lua/custom/loader/INTEGRATION.lua
-- Reference integration file.
-- Copy relevant blocks into your lua/custom/init.lua (or equivalent entry point).
-- This file is NOT required — it is documentation-as-code.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1 — Put this at the very top of lua/custom/init.lua
-- ─────────────────────────────────────────────────────────────────────────────

local loader = require("custom.loader")

loader.setup({
  -- Set profile = true while tuning; disable in daily use to avoid overhead.
  profile = false,
  -- Verbose require/skip/fail logging.
  debug = false,
  -- Milliseconds after VimEnter before the deferred queue flushes.
  -- 100 ms keeps the first frame responsive; raise to 200 on slow machines.
  defer_timeout = 100,
  -- Modules processed per CursorHold tick during idle loading.
  idle_batch = 3,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2 — Register your modules
-- ─────────────────────────────────────────────────────────────────────────────

loader.register({

  -- ── Critical (load synchronously during bootstrap) ───────────────────────
  -- These block startup intentionally; keep the list short.

  { mod = "custom.settings", priority = "critical" },
  { mod = "custom.keymaps", priority = "critical", deps = { "custom.settings" } },

  -- ── Deferred (loaded 100 ms after VimEnter, dependency-ordered) ──────────

  { mod = "custom.ui.statusline", defer = true, deps = { "custom.settings" } },
  { mod = "custom.ui.tabline", defer = true, deps = { "custom.ui.statusline" } },
  { mod = "custom.tools.git", defer = true },
  { mod = "custom.tools.format", defer = true },

  -- ── Idle (loaded during CursorHold — purely non-critical background work) ─

  { mod = "custom.telemetry", idle = true },
  { mod = "custom.analytics", idle = true },

  -- ── Event-triggered ──────────────────────────────────────────────────────

  -- Loads as soon as LSP attaches; no cost if no LSP.
  { mod = "custom.lsp.config", event = "LspAttach" },

  -- Loads the first time any buffer is read (good for project-awareness tools).
  { mod = "custom.project", event = { "BufReadPre", "BufNewFile" } },

  -- ── Filetype-triggered ───────────────────────────────────────────────────

  { mod = "custom.lang.python", ft = "python" },
  { mod = "custom.lang.typescript", ft = { "typescript", "typescriptreact" } },
  { mod = "custom.lang.rust", ft = "rust" },
  { mod = "custom.lang.go", ft = "go" },
  { mod = "custom.lang.lua", ft = "lua", deps = { "custom.settings" } },

  -- ── Command-triggered ────────────────────────────────────────────────────
  -- A stub command is created immediately; the real module loads on first use.

  { mod = "custom.debug", cmd = { "DebugStart", "DebugAttach" } },
  { mod = "custom.rest", cmd = "RestRun" },
  { mod = "custom.db", cmd = { "DBConnect", "DBQuery" } },

  -- ── Keymap-triggered ─────────────────────────────────────────────────────
  -- A stub keymap is created; the real module loads on first press.
  -- Pass { lhs, mode = "..." } for non-normal modes.

  { mod = "custom.finder", keys = { "<leader>ff", "<leader>fg" } },
  {
    mod = "custom.notes",
    keys = { { "<leader>nn", mode = "n" }, { "<leader>nn", mode = "v" } },
  },

  -- ── Conditional ──────────────────────────────────────────────────────────
  -- Module is skipped entirely when cond returns false.

  {
    mod = "custom.remote",
    cond = function()
      return vim.fn.executable("ssh") == 1
    end,
    idle = true,
  },

  {
    mod = "custom.copilot",
    cond = function()
      return vim.g.use_copilot == true
    end,
    event = "InsertEnter",
  },

  -- ── With post-load config callback ───────────────────────────────────────

  {
    mod = "custom.tools.format",
    defer = true,
    config = function(fmt_module)
      fmt_module.setup({ on_save = true, timeout_ms = 2000 })
    end,
  },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3 — Bootstrap (call exactly once, after all register() calls)
-- ─────────────────────────────────────────────────────────────────────────────

loader.bootstrap()

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4 — On-demand loading anywhere in your config
-- ─────────────────────────────────────────────────────────────────────────────

-- Load a module immediately (safe to call even if already loaded).
-- loader.load("custom.lsp.config")

-- Force-reload after editing (dev workflow).
-- loader.reload("custom.tools.format")

-- Query state.
-- if loader.is_loaded("custom.lsp.config") then ... end
-- print(loader.state("custom.lang.python"))  -- "registered", "loaded", etc.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5 — Debug commands (available once setup() runs)
-- ─────────────────────────────────────────────────────────────────────────────

-- :LoaderStats            — overview: states, queues, startup elapsed, duplicates
-- :LoaderProfile          — per-module timing (requires profile=true)
-- :LoaderModules          — full registry with states and load order
-- :LoaderSlowmods [N]     — modules slower than N ms (default 5)
-- :LoaderReload <module>  — force-reload; tab-completion works

-- ─────────────────────────────────────────────────────────────────────────────
-- ARCHITECTURE DECISION GUIDE
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Use  priority = "critical"   for:
--   Options (vim.opt.*), global variables, remaps that every other module needs.
--   Keep this list to ≤ 5 modules. If your critical list is long, something
--   is wrong — most things can defer.
--
-- Use  defer = true  (default for non-critical) for:
--   UI chrome (statusline, tabline), project tools, formatters, diagnostics.
--   These are needed within seconds of opening a file, not at frame 0.
--
-- Use  idle = true  for:
--   Telemetry, analytics, background sync, anything the user never waits for.
--
-- Use  event =  for:
--   LSP config, TreeSitter, anything that only makes sense once an event fires.
--
-- Use  ft =  for:
--   Language-specific tooling. Zero cost for unrelated filetypes.
--
-- Use  cmd =  for:
--   Heavy tools (DAP, REST client, DB browser) that are rarely invoked.
--
-- Use  keys =  for:
--   Features accessed via a specific leader key that aren't needed at startup.
--
-- Avoid loading everything eagerly. The loader's value is proportional to
-- how many modules you keep out of the critical path.
