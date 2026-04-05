-- tabline/init.lua
-- Public API and entry point.
--
-- Users call:
--   require("custom.tabline").setup({ ... })
--
-- Public functions (usable in keymaps or commands):
--   require("custom.tabline").next_buffer()
--   require("custom.tabline").prev_buffer()
--   require("custom.tabline").close_buffer()
--   require("custom.tabline").move_buffer_left()
--   require("custom.tabline").move_buffer_right()

local M = {}
local nvim_utils = require("utils.nvim")

local _config     = nil
local _buffers    = nil
local _render     = nil
local _highlights = nil
local _mouse      = nil
local _session    = nil

-- ─── tabline entry point ──────────────────────────────────────────────────

--- Called by Neovim on every tabline redraw via:
---   vim.o.tabline = "%!v:lua.require'tabline'.render()"
---@return string
function M.render()
  if not _render then return "" end
  return _render.render()
end

-- ─── buffer navigation ────────────────────────────────────────────────────

function M.next_buffer()
  if not _buffers then return end
  local bufs    = _buffers.get_buffers()
  if #bufs == 0 then return end
  local current = vim.api.nvim_get_current_buf()
  local idx     = _buffers.get_index(current) or 0
  local next_b  = bufs[(idx % #bufs) + 1]  -- wraps: last → first
  if next_b and next_b ~= current then
    vim.api.nvim_set_current_buf(next_b)
  end
end

function M.prev_buffer()
  if not _buffers then return end
  local bufs    = _buffers.get_buffers()
  if #bufs == 0 then return end
  local current = vim.api.nvim_get_current_buf()
  -- FIX #8: Default to idx=1 (not 2) when current is not in the list.
  -- With idx=1: ((1-2) % n)+1 = n, which correctly wraps to the last buffer.
  -- With the old idx=2: ((2-2) % n)+1 = 1, which jumped to the first buffer
  -- instead of wrapping to the last — wrong direction for a "previous" action.
  local idx     = _buffers.get_index(current) or 1
  local prev_b  = bufs[((idx - 2) % #bufs) + 1]  -- wraps: first → last
  if prev_b and prev_b ~= current then
    vim.api.nvim_set_current_buf(prev_b)
  end
end

-- ─── buffer management ────────────────────────────────────────────────────

function M.close_buffer(bufnr)
  if not _buffers then return end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.close(target, _config.focus_on_close)
end

function M.move_buffer_left(bufnr)
  if not _buffers then return end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_left(target)
  vim.cmd("redrawtabline")
end

function M.move_buffer_right(bufnr)
  if not _buffers then return end
  local target = bufnr or vim.api.nvim_get_current_buf()
  _buffers.move_right(target)
  vim.cmd("redrawtabline")
end

-- ─── keymaps ──────────────────────────────────────────────────────────────

local function bind(lhs, fn, desc)
  nvim_utils.map("n", lhs, fn, { silent = true, noremap = true, desc = desc })
end

local function setup_keymaps(km)
  bind(km.next,       M.next_buffer,       "TabLine: next buffer")
  bind(km.prev,       M.prev_buffer,       "TabLine: prev buffer")
  bind(km.close,      M.close_buffer,      "TabLine: close buffer")
  bind(km.move_left,  M.move_buffer_left,  "TabLine: move buffer left")
  bind(km.move_right, M.move_buffer_right, "TabLine: move buffer right")
end

-- ─── autocmds ─────────────────────────────────────────────────────────────

local function setup_autocmds()
  local grp = nvim_utils.augroup("TablinePlugin")

  -- Standard redraw events: buffer list changes or active buffer changes
  nvim_utils.autocmd({
    "BufAdd",
    "BufDelete",
    "BufEnter",
    "BufModifiedSet",
    "SessionLoadPost",
    "TabClosed",
  }, {
    group    = grp,
    callback = function()
      vim.schedule(function() vim.cmd("redrawtabline") end)
    end,
  })

  -- FIX #9: BufReadPost fires after the file is read into the buffer.
  -- This is the event that actually sets the buffer name when you do
  -- `:e file` on an existing [No Name] buffer, or open files from the CLI.
  -- BufNewFile fires for brand-new (non-existent) files.
  -- BufFilePost fires after :file or :saveas renames the buffer.
  -- All three must explicitly bust the name cache — the fingerprint alone
  -- is not sufficient because the cache is keyed by the visible slice and
  -- a BufEnter scheduled redraw might fire BEFORE the file name is set.
  nvim_utils.autocmd({
    "BufReadPost",
    "BufNewFile",
    "BufFilePost",
  }, {
    group    = grp,
    callback = function()
      -- Bust the name cache immediately (synchronously), then schedule
      -- the visual redraw so it runs with the fully-updated name.
      if _render then _render.invalidate_name_cache() end
      vim.schedule(function() vim.cmd("redrawtabline") end)
    end,
  })

  -- Re-apply highlights whenever the colorscheme changes
  nvim_utils.autocmd("ColorScheme", {
    group    = grp,
    callback = function()
      _highlights.setup()
    end,
  })

  -- ── Session persistence ────────────────────────────────────────────────
  -- Only register if the feature is enabled.
  if not (_config.persist and _config.persist.enabled) then return end

  -- SAVE: triggered on normal exit (:qa, :wqa …)
  -- VimLeavePre fires reliably when you quit via commands.
  nvim_utils.autocmd("VimLeavePre", {
    group    = grp,
    callback = function()
      if _config.persist.save_on_exit and _session then
        -- Use the saved-this-session guard exposed on the module so UILeave
        -- (fired slightly later on some terminals) does not double-write.
        _session.save_on_exit_handler(vim.fn.getcwd())
      end
    end,
  })

  -- SAVE: fallback for terminal window being killed without :quit.
  -- When you close the terminal emulator, the kernel sends SIGHUP.
  -- VimLeavePre still fires in most cases BUT on certain terminal emulators
  -- (Kitty, Konsole) all buffers are already marked unloaded before it runs.
  -- UILeave fires earlier in the shutdown sequence and sees valid state.
  -- Research: https://github.com/stevearc/resession.nvim/issues/49
  nvim_utils.autocmd("UILeave", {
    group    = grp,
    callback = function()
      if _config.persist.save_on_exit and _session then
        _session.save_on_exit_handler(vim.fn.getcwd())
      end
    end,
  })

  -- RESTORE: fires after all plugins have loaded and the UI is ready.
  -- We use VimEnter (not UIEnter) because UIEnter may fire too early for
  -- some lazy-loaders.  vim.schedule() defers past any remaining plugin init.
  -- Guard: only restore when Neovim was opened with no file/dir arguments
  -- (argc == 0).  Opening `nvim myfile.lua` should never clobber the argument.
  nvim_utils.autocmd("VimEnter", {
    group    = grp,
    once     = true,   -- only ever fires once per session
    callback = function()
      if not _config.persist.restore_on_startup then return end

      -- Headless detection must happen here, before vim.schedule(), while
      -- the UI list reflects the actual launch mode.
      -- vim.fn.has("vim_starting") is NOT correct — "vim_starting" is not a
      -- recognised Neovim feature flag and has() always returns 0 for it,
      -- causing the guard to always fire and silently skip every restore.
      -- nvim_list_uis() returns an empty table in --headless mode and a
      -- populated one when a real UI (TUI or GUI) is attached.
      if #vim.api.nvim_list_uis() == 0 then return end

      vim.schedule(function()
        -- Don't restore if the user passed file arguments on the command line.
        if vim.fn.argc() > 0 then return end

        -- Don't restore if another plugin has already loaded real buffers
        -- (e.g. a dashboard plugin that pre-populates the buffer list).
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.fn.buflisted(b) == 1
             and vim.api.nvim_buf_get_name(b) ~= "" then
            return
          end
        end

        if _session then
          _session.restore(vim.fn.getcwd(), true)
        end
      end)
    end,
  })
end

-- ─── user commands ────────────────────────────────────────────────────────

local function setup_commands()
  -- FIX #10: Pass force=true so re-calling setup() does not raise
  -- "command already exists" errors.
  local opts = { force = true }

  nvim_utils.command("TablineNext",
    M.next_buffer, vim.tbl_extend("force", opts, { desc = "TabLine: next buffer" }))

  nvim_utils.command("TablinePrev",
    M.prev_buffer, vim.tbl_extend("force", opts, { desc = "TabLine: prev buffer" }))

  nvim_utils.command("TablineClose", function(o)
    M.close_buffer(o.args ~= "" and tonumber(o.args) or nil)
  end, vim.tbl_extend("force", opts, { nargs = "?", desc = "TabLine: close buffer" }))

  nvim_utils.command("TablineMoveLeft",
    M.move_buffer_left, vim.tbl_extend("force", opts, { desc = "TabLine: move buffer left" }))

  nvim_utils.command("TablineMoveRight",
    M.move_buffer_right, vim.tbl_extend("force", opts, { desc = "TabLine: move buffer right" }))

  -- Session commands (always registered; they are no-ops when persist is disabled)
  nvim_utils.command("TablineSessionSave", function()
    M.session_save()
  end, vim.tbl_extend("force", opts, { desc = "TabLine: manually save session" }))

  nvim_utils.command("TablineSessionRestore", function()
    M.session_restore()
  end, vim.tbl_extend("force", opts, { desc = "TabLine: manually restore session" }))

  nvim_utils.command("TablineSessionDelete", function()
    M.session_delete()
  end, vim.tbl_extend("force", opts, { desc = "TabLine: delete session for cwd" }))

  nvim_utils.command("TablineSessionList", function()
    M.session_list_print()
  end, vim.tbl_extend("force", opts, { desc = "TabLine: list all saved sessions" }))
end

-- ─── setup ────────────────────────────────────────────────────────────────

---@param user_config table|nil
function M.setup(user_config)
  local config_mod = require("custom.tabline.config")
  _highlights      = require("custom.tabline.highlights")
  _buffers         = require("custom.tabline.buffers")
  _render          = require("custom.tabline.render")
  _mouse           = require("custom.tabline.mouse")
  _session         = require("custom.tabline.session")

  _config = config_mod.apply(user_config)

  _highlights.setup()
  _render.setup(_config)
  _mouse.setup(_config)
  _session.setup(_config.persist)

  vim.o.showtabline = 2
  vim.o.tabline     = "%!v:lua.require'custom.tabline'.render()"

  setup_keymaps(_config.keymaps)
  setup_autocmds()   -- augroup is cleared then recreated → idempotent
  setup_commands()   -- force=true → idempotent
end

--- Allow overriding individual highlight groups after setup.
---@param name string
---@param opts table
function M.set_highlight(name, opts)
  if _highlights then _highlights.override(name, opts) end
end

-- ─── session public API ───────────────────────────────────────────────────

--- Manually save the session for the current working directory.
function M.session_save()
  if not _session then
    vim.notify("tabline: not initialised", vim.log.levels.WARN)
    return
  end
  if not (_config.persist and _config.persist.enabled) then
    vim.notify("tabline: persist is disabled", vim.log.levels.WARN)
    return
  end
  _session.save(vim.fn.getcwd(), false)
end

--- Manually restore the session for the current working directory.
function M.session_restore()
  if not _session then return end
  if not (_config.persist and _config.persist.enabled) then
    vim.notify("tabline: persist is disabled", vim.log.levels.WARN)
    return
  end
  _session.restore(vim.fn.getcwd(), true)
end

--- Delete the saved session for the current working directory.
function M.session_delete()
  if not _session then return end
  local cwd = vim.fn.getcwd()
  local ok  = _session.delete(cwd)
  if ok then
    vim.notify("tabline: session deleted for " .. cwd, vim.log.levels.INFO)
  else
    vim.notify("tabline: no session found for " .. cwd, vim.log.levels.WARN)
  end
end

--- Print a list of all saved sessions to the messages area.
function M.session_list_print()
  if not _session then return end
  local sessions = _session.list()
  if #sessions == 0 then
    vim.notify("tabline: no saved sessions", vim.log.levels.INFO)
    return
  end
  local lines = { "tabline sessions:" }
  for _, s in ipairs(sessions) do
    local ts = s.saved_at and os.date("%Y-%m-%d %H:%M", s.saved_at) or "unknown time"
    lines[#lines + 1] = string.format("  %s  [%d bufs]  %s",
      ts, s.count or 0, s.cwd)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
