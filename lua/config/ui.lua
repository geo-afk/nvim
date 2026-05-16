-- =============================================================================
--  config/ui.lua  ·  Visual & UX layer
--
--  Covers:
--    • ui2 (experimental redesigned message/cmdline UI)
-- =============================================================================

-- =============================================================================
--  UI2 – EXPERIMENTAL REDESIGNED MESSAGE / CMDLINE UI  (0.12-new)
-- =============================================================================
-- NEOVIM 0.11 → 0.12 COMPARISON:
--   0.11:  The message grid is monolithic; "Press ENTER" prompts are frequent.
--          Long command output requires scrolling through a temporary overlay.
--
--   0.12:  ui2 decouples messages from the core grid.  Benefits:
--            • No "Press ENTER" interruptions.
--            • Delays from W10 "Changing a readonly file" warnings are gone.
--            • Cmdline is highlighted as you type.
--            • Pager is a real buffer (scrollable, searchable with /).
--            • :restart / :connect work because the UI is detached from core.
--          Currently experimental – enable with the call below.

local ok_ui2 = pcall(function()
  require("vim._core.ui2").enable({
    enable = true,
    msg = {
      -- "cmd" = messages appear in cmdline area (default, less intrusive)
      -- "msg" = messages appear in a separate ephemeral floating window
      -- targets = "msg",
      targets = {
        [""] = "msg",
        empty = "cmd",
        bufwrite = "msg",
        confirm = "cmd",
        emsg = "pager",
        echo = "msg",
        echomsg = "msg",
        echoerr = "pager",
        completion = "cmd",
        list_cmd = "pager",
        lua_error = "pager",
        lua_print = "msg",
        progress = "pager",
        rpc_error = "pager",
        quickfix = "msg",
        search_cmd = "cmd",
        search_count = "cmd",
        shell_cmd = "pager",
        shell_err = "pager",
        shell_out = "pager",
        shell_ret = "msg",
        undo = "msg",
        verbose = "pager",
        wildlist = "cmd",
        wmsg = "msg",
        typed_cmd = "cmd",
      },
      cmd = {
        -- Maximum height of the expanded cmdline message area (fraction of win)
        height = 0.1,
      },
      dialog = {
        height = 0.4, -- dialog boxes
      },
      msg = {
        height = 0.3,
        timeout = 5000, -- ms before the ephemeral message disappears
      },
      pager = {
        height = 0.4, -- pager buffer height when viewing long output
      },
    },
  })
end)

if not ok_ui2 then
  vim.notify("ui2 is not available in this Neovim build; upgrade to 0.12+", vim.log.levels.WARN)
end

-- Load the showcase in the background (commands only)
vim.schedule(function()
  pcall(function()
    require("config.ui_showcase").setup()
  end)

  -- Go Import highlights
  vim.api.nvim_set_hl(0, "@module.last", { link = "Type", bold = true, italic = true })
end)
