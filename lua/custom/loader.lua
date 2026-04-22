-- =============================================================================
-- loader.lua — Fail-safe deferred loading helpers for Neovim 0.12+
-- =============================================================================
-- Loading helpers used to organise config into fail-safe parts.
--
-- Usage:
--   local Loader = require("loader")
--
--   -- Execute immediately (colorscheme, statusline, etc.)
--   Loader.now(function() vim.cmd("colorscheme habamax") end)
--
--   -- Execute after startup is fully done
--   Loader.later(function() require("my_heavy_plugin").setup() end)
--
--   -- Execute once, on first matching event
--   Loader.on_event("InsertEnter", function() require("cmp").setup() end)
--
--   -- Execute once, on first matching filetype
--   Loader.on_filetype("lua", function() require("neodev").setup() end)
-- =============================================================================

local Loader = {}

-- Internal error reporter — wraps pcall and surfaces errors without crashing.
---@param desc string  Human-readable label shown in the error message.
---@param fn   fun()   The function to execute safely.
local function safe_call(desc, fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.schedule(function()
      vim.notify(
        ("[loader] Error in %s:\n%s"):format(desc, tostring(err)),
        vim.log.levels.ERROR,
        { title = "loader.lua" }
      )
    end)
  end
end

-- =============================================================================
-- now — execute immediately, during startup
-- =============================================================================
-- Use for anything that MUST be in place before the first screen draw:
--   colorschemes, statuslines, tablines, dashboards, core options, keymaps.
--
-- Errors are caught and reported via vim.notify so a single bad block cannot
-- abort the rest of your config.
--
---@param fn fun()  Function to execute right now.
function Loader.now(fn)
  safe_call("now()", fn)
end

-- =============================================================================
-- later — execute after Neovim has fully started
-- =============================================================================
-- Defers work until the event loop is idle (via vim.schedule), which keeps
-- startup snappy. Ideal for:
--   plugin setup, LSP servers, formatters, heavy UI tweaks.
--
-- All `later` callbacks are queued and run in FIFO order once the UI is ready.
--
---@param fn fun()  Function to defer until after startup.
function Loader.later(fn)
  vim.schedule(function()
    safe_call("later()", fn)
  end)
end

-- =============================================================================
-- on_event — execute once on the first occurrence of an event (or event list)
-- =============================================================================
-- Creates a one-shot autocmd. After the callback fires the autocmd is deleted.
-- The callback also fires immediately if Neovim has already passed that event
-- (e.g., VimEnter when called from an already-running session).
--
-- Examples:
--   Loader.on_event("InsertEnter",          function() ... end)
--   Loader.on_event({"BufReadPre","BufNew"}, function() ... end)
--
---@param events  string|string[]   Neovim event name(s).
---@param fn      fun()             Callback — runs exactly once.
---@param opts?   table             Extra options forwarded to nvim_create_autocmd
--                                  (e.g., { pattern = "*.lua" }).
function Loader.on_event(events, fn, opts)
  opts = opts or {}

  -- Normalise to a list so LuaLS and table.concat always see a string[].
  ---@type string[]
  local event_list = type(events) == "string" and { events } or events --[[@as string[] ]]

  -- One-shot group — cleared after first fire.
  local group_name = "LoaderOnEvent_" .. table.concat(event_list, "_")
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  local autocmd_id

  -- `_` discards the autocmd callback arg; we don't need event details.
  local wrapped = function(_)
    -- Delete the autocmd before calling the user fn so re-entrant events
    -- cannot trigger a second execution.
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
    vim.api.nvim_del_augroup_by_name(group_name)
    safe_call(("on_event(%s)"):format(table.concat(event_list, ", ")), fn)
  end

  ---@type vim.api.keyset.create_autocmd
  local autocmd_opts = vim.tbl_extend("force", opts, {
    group = group,
    once = true,
    callback = wrapped,
  }) --[[@as vim.api.keyset.create_autocmd]]

  autocmd_id = vim.api.nvim_create_autocmd(event_list, autocmd_opts)
end

-- =============================================================================
-- on_filetype — execute once on the first buffer whose filetype matches
-- =============================================================================
-- Creates a one-shot FileType autocmd. After the first match the autocmd is
-- removed. Accepts a single filetype string, a comma-separated string, or a
-- list of strings (all are normalised to a pattern list automatically).
--
-- Examples:
--   Loader.on_filetype("lua",            function() ... end)
--   Loader.on_filetype({"lua","python"},  function() ... end)
--   Loader.on_filetype("lua,python",      function() ... end)
--
---@param filetypes  string|string[]  Filetype(s) to match.
---@param fn         fun()            Callback — runs exactly once.
function Loader.on_filetype(filetypes, fn)
  -- Normalise to a flat list of strings.
  local ft_list
  if type(filetypes) == "string" then
    ft_list = vim.split(filetypes, ",", { trimempty = true })
  else
    ft_list = filetypes
  end

  -- Trim whitespace from each entry.
  for i, v in ipairs(ft_list) do
    ft_list[i] = v:match("^%s*(.-)%s*$")
  end

  local group_name = "LoaderOnFt_" .. table.concat(ft_list, "_")
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  local autocmd_id

  local wrapped = function()
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
    vim.api.nvim_del_augroup_by_name(group_name)
    safe_call(("on_filetype(%s)"):format(table.concat(ft_list, ", ")), fn)
  end

  autocmd_id = vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = ft_list,
    once = true,
    callback = wrapped,
  })
end

-- =============================================================================
-- on_keys — execute once when ANY of the given key sequences is pressed
-- (bonus helper: useful for lazy-loading motion/operator plugins)
-- =============================================================================
-- Uses vim.keymap.set with a one-shot wrapper. The key reverts to its original
-- behaviour after the first press.
--
-- Example:
--   Loader.on_keys({"<leader>f", "<leader>g"}, function()
--     require("telescope").setup()
--   end)
--
---@param keys  string[]   List of key sequences (normal mode by default).
---@param fn    fun()      Setup callback — runs exactly once on first press.
---@param mode? string     Vim mode string, defaults to "n".
function Loader.on_keys(keys, fn, mode)
  mode = mode or "n"
  local fired = false

  for _, key in ipairs(keys) do
    -- Capture `key` in the closure to restore it correctly.
    local k = key
    vim.keymap.set(mode, k, function()
      if not fired then
        fired = true
        -- Remove all shim mappings before calling setup so the user fn can
        -- re-map them properly.
        for _, kk in ipairs(keys) do
          pcall(vim.keymap.del, mode, kk)
        end
        safe_call(("on_keys(%s)"):format(k), fn)
      end
      -- Re-feed the key so the action still happens after setup.
      local feed = vim.api.nvim_replace_termcodes(k, true, false, true)
      vim.api.nvim_feedkeys(feed, mode, false)
    end, { desc = "[loader] lazy-load on " .. k })
  end
end

return Loader
