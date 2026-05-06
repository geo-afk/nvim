-- debugger_config.lua — keymaps, user commands, autocmds
-- Call require("custom.go.debugger_config").setup() from init.lua

local M = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {
    prefix = "<leader>d",
  }, opts or {})

  local dbg = require("custom.go.debugger")
  local ui = require("custom.go.debugger_ui")

  dbg.setup()

  -- ─── helpers ────────────────────────────────────────────────────────────────

  local function map(mode, suffix, fn, desc, extra)
    vim.keymap.set(
      mode,
      opts.prefix .. suffix,
      fn,
      vim.tbl_extend("force", { silent = true, desc = "[go-debug] " .. desc }, extra or {})
    )
  end

  -- ─── session-scoped arrow keymaps ───────────────────────────────────────────

  local session_maps = {}

  local function install_session_keys()
    local function sm(lhs, rhs, desc)
      table.insert(session_maps, lhs)
      vim.keymap.set("n", lhs, rhs, { silent = true, desc = "[dbg] " .. desc })
    end
    sm("<F5>", dbg.continue, "continue")
    sm("<F10>", dbg.step_over, "step over")
    sm("<F11>", dbg.step_into, "step into")
    sm("<F12>", dbg.step_out, "step out")
    sm("<Down>", dbg.step_over, "step over")
    sm("<Right>", dbg.step_into, "step into")
    sm("<Left>", dbg.step_out, "step out")
    sm("<Up>", dbg.continue, "continue")
  end

  local function remove_session_keys()
    for _, lhs in ipairs(session_maps) do
      pcall(vim.keymap.del, "n", lhs)
    end
    session_maps = {}
  end

  -- wrap start/stop to manage session-scoped keys
  local _debug = dbg.debug
  local _test = dbg.test
  local _attach = dbg.attach
  local _attach_sp = dbg.attach_spawn
  local _connect = dbg.connect
  local _restart = dbg.restart
  local _stop = dbg.stop

  dbg.debug = function(...)
    install_session_keys()
    _debug(...)
  end
  dbg.test = function(...)
    install_session_keys()
    _test(...)
  end
  dbg.attach = function(...)
    install_session_keys()
    _attach(...)
  end
  dbg.attach_spawn = function(...)
    install_session_keys()
    _attach_sp(...)
  end
  dbg.connect = function(...)
    install_session_keys()
    _connect(...)
  end
  dbg.restart = function(...)
    install_session_keys()
    _restart(...)
  end
  dbg.stop = function(...)
    remove_session_keys()
    _stop(...)
  end

  -- ─── launch ─────────────────────────────────────────────────────────────────

  map("n", "d", dbg.debug, "debug main package")
  map("n", "t", dbg.test, "debug test package")
  map("n", "b", dbg.attach_spawn, "build + debug binary")
  map("n", "a", dbg.attach_select, "attach to process")
  map("n", "C", function()
    vim.ui.input({ prompt = "Connect (host:port): " }, function(v)
      if v and v ~= "" then
        dbg.connect(v)
      end
    end)
  end, "connect to headless dlv")
  map("n", "r", dbg.restart, "restart last session")
  map("n", "q", dbg.stop, "stop session")

  -- ─── execution ──────────────────────────────────────────────────────────────

  map("n", "c", dbg.continue, "continue")
  map("n", "n", dbg.step_over, "step over")
  map("n", "s", dbg.step_into, "step into")
  map("n", "o", dbg.step_out, "step out")
  map("n", "z", dbg.pause, "pause")
  map("n", "g", dbg.run_to_cursor, "run to cursor")

  -- ─── breakpoints ────────────────────────────────────────────────────────────

  map("n", "p", dbg.toggle_breakpoint, "toggle breakpoint")
  map("n", "P", dbg.conditional_breakpoint, "conditional breakpoint")
  map("n", "L", dbg.logpoint, "logpoint")
  map("n", "H", dbg.hit_breakpoint, "hit-count breakpoint")
  map("n", "x", dbg.remove_breakpoint, "remove breakpoint")
  map("n", "X", dbg.clear_breakpoints, "clear all breakpoints")
  map("n", "l", dbg.list_breakpoints, "list breakpoints")

  -- ─── inspection ─────────────────────────────────────────────────────────────

  map("n", "k", function()
    dbg.hover_eval()
  end, "hover eval word")
  map("v", "k", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
    dbg.hover_eval(vim.trim(table.concat(lines, " ")))
  end, "hover eval selection")
  map("n", "e", function()
    dbg.inspect()
  end, "inspect expression")
  map("n", "E", dbg.set_variable, "set variable value")
  map("n", "v", dbg.variables, "refresh variables")
  map("n", "S", dbg.stack, "refresh stack")

  -- ─── watches ────────────────────────────────────────────────────────────────

  map("n", "w", function()
    dbg.watch_add()
  end, "add watch")
  map("v", "w", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
    dbg.watch_add(vim.trim(table.concat(lines, " ")))
  end, "watch selection")
  map("n", "W", dbg.watch_remove, "remove watch")

  -- ─── UI ─────────────────────────────────────────────────────────────────────

  map("n", "u", ui.toggle, "toggle debug UI")

  -- ─── user commands ──────────────────────────────────────────────────────────

  local cmds = {
    GoDlvDebug = { fn = dbg.debug, nargs = 0 },
    GoDlvTest = { fn = dbg.test, nargs = 0 },
    GoDlvBuild = { fn = dbg.attach_spawn, nargs = 0 },
    GoDlvAttach = { fn = dbg.attach_select, nargs = 0 },
    GoDlvConnect = {
      fn = function(i)
        dbg.connect(i.args ~= "" and i.args or nil)
      end,
      nargs = "?",
    },
    GoDlvRestart = { fn = dbg.restart, nargs = 0 },
    GoDlvStop = { fn = dbg.stop, nargs = 0 },
    GoDlvContinue = { fn = dbg.continue, nargs = 0 },
    GoDlvNext = { fn = dbg.step_over, nargs = 0 },
    GoDlvStep = { fn = dbg.step_into, nargs = 0 },
    GoDlvOut = { fn = dbg.step_out, nargs = 0 },
    GoDlvPause = { fn = dbg.pause, nargs = 0 },
    GoDlvRunToCursor = { fn = dbg.run_to_cursor, nargs = 0 },
    GoDlvBreakpoint = { fn = dbg.toggle_breakpoint, nargs = 0 },
    GoDlvCondBreakpoint = {
      fn = function(i)
        dbg.conditional_breakpoint(i.args ~= "" and i.args or nil)
      end,
      nargs = "?",
    },
    GoDlvLogpoint = { fn = dbg.logpoint, nargs = 0 },
    GoDlvHitBreakpoint = { fn = dbg.hit_breakpoint, nargs = 0 },
    GoDlvClearBPs = { fn = dbg.clear_breakpoints, nargs = 0 },
    GoDlvInspect = {
      fn = function(i)
        dbg.inspect(i.args ~= "" and i.args or nil)
      end,
      nargs = "?",
    },
    GoDlvSetVar = { fn = dbg.set_variable, nargs = 0 },
    GoDlvWatch = {
      fn = function(i)
        dbg.watch_add(i.args ~= "" and i.args or nil)
      end,
      nargs = "?",
    },
    GoDlvWatchRemove = { fn = dbg.watch_remove, nargs = 0 },
    GoDlvUI = { fn = ui.toggle, nargs = 0 },
  }

  for name, spec in pairs(cmds) do
    vim.api.nvim_create_user_command(name, spec.fn, { nargs = spec.nargs })
  end

  -- ─── autocmds ───────────────────────────────────────────────────────────────

  local aug = vim.api.nvim_create_augroup("GoDebugConfig", { clear = true })

  -- Re-place BP signs when a Go buffer is loaded
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
    group = aug,
    pattern = "*.go",
    callback = function()
      local bps = dbg.list_breakpoints()
      ui.render_breakpoint_signs(bps)
    end,
  })

  -- Auto-close UI when no real editor windows remain
  vim.api.nvim_create_autocmd("WinClosed", {
    group = aug,
    callback = function()
      local have_editor = false
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
        if ft ~= "godebug" and ft ~= "" then
          have_editor = true
          break
        end
      end
      if not have_editor then
        vim.schedule(ui.close)
      end
    end,
  })

  -- Kill dlv cleanly on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = aug,
    once = true,
    callback = function()
      pcall(dbg.stop)
    end,
  })
end

return M
