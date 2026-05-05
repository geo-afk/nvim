-- debugger_config.lua — keymaps, user commands, and autocmds for go-debug
-- Place alongside debugger.lua and debugger_ui.lua.
-- Call require("custom.go.debugger_config").setup() from your init.lua.

local M = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {
    -- Key prefix for all debug bindings (default: <leader>d)
    prefix = "<leader>d",
    -- Only attach Go-file keymaps in .go buffers
    go_only = true,
  }, opts or {})

  local dbg = require("custom.go.debugger")
  local ui = require("custom.go.debugger_ui")

  dbg.setup()

  -- ─── helper ────────────────────────────────────────────────────────────────

  local function map(mode, suffix, fn, desc, extra_opts)
    local lhs = opts.prefix .. suffix
    vim.keymap.set(
      mode,
      lhs,
      fn,
      vim.tbl_extend("force", { silent = true, desc = "[go-debug] " .. desc }, extra_opts or {})
    )
  end

  -- ─── launch ───────────────────────────────────────────────────────────────

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
  map("n", "q", dbg.stop, "stop session")

  -- ─── execution control ────────────────────────────────────────────────────

  map("n", "c", dbg.continue, "continue")
  map("n", "n", dbg.step_over, "step over")
  map("n", "s", dbg.step_into, "step into")
  map("n", "o", dbg.step_out, "step out")

  -- ─── breakpoints ─────────────────────────────────────────────────────────

  map("n", "p", dbg.toggle_breakpoint, "toggle breakpoint")
  map("n", "P", dbg.conditional_breakpoint, "conditional breakpoint")
  map("n", "X", dbg.clear_breakpoints, "clear all breakpoints")
  map("n", "l", dbg.list_breakpoints, "list breakpoints")

  -- ─── inspection ──────────────────────────────────────────────────────────

  map("n", "k", function()
    dbg.inspect()
  end, "inspect expression")
  map("v", "k", function()
    -- inspect visual selection
    local s = vim.fn.getpos("'<")
    local e = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_text(0, s[2] - 1, s[3] - 1, e[2] - 1, e[3], {})
    dbg.inspect(table.concat(lines, " "))
  end, "inspect selection")
  map("n", "v", dbg.variables, "show variables")
  map("n", "S", dbg.stack, "show stack")

  -- ─── UI ──────────────────────────────────────────────────────────────────

  map("n", "u", ui.toggle, "toggle debug UI")

  -- ─── user commands ────────────────────────────────────────────────────────

  local cmds = {
    GoDlvDebug = { fn = dbg.debug, desc = "Debug main package" },
    GoDlvTest = { fn = dbg.test, desc = "Debug test package" },
    GoDlvBuild = { fn = dbg.attach_spawn, desc = "Build & debug binary" },
    GoDlvAttach = { fn = dbg.attach_select, desc = "Attach to running process" },
    GoDlvConnect = {
      fn = function(info)
        dbg.connect(info.args ~= "" and info.args or nil)
      end,
      desc = "Connect to headless dlv (host:port)",
      nargs = "?",
    },
    GoDlvStop = { fn = dbg.stop, desc = "Stop debug session" },
    GoDlvContinue = { fn = dbg.continue, desc = "Continue" },
    GoDlvNext = { fn = dbg.step_over, desc = "Step over" },
    GoDlvStep = { fn = dbg.step_into, desc = "Step into" },
    GoDlvOut = { fn = dbg.step_out, desc = "Step out" },
    GoDlvBreakpoint = { fn = dbg.toggle_breakpoint, desc = "Toggle breakpoint" },
    GoDlvCondBreakpoint = {
      fn = function(info)
        dbg.conditional_breakpoint(info.args ~= "" and info.args or nil)
      end,
      desc = "Set conditional breakpoint (expr)",
      nargs = "?",
    },
    GoDlvClearBPs = { fn = dbg.clear_breakpoints, desc = "Clear all breakpoints" },
    GoDlvInspect = {
      fn = function(info)
        dbg.inspect(info.args ~= "" and info.args or nil)
      end,
      desc = "Inspect expression",
      nargs = "?",
    },
    GoDlvUI = { fn = ui.toggle, desc = "Toggle debugger UI" },
  }

  for name, spec in pairs(cmds) do
    vim.api.nvim_create_user_command(name, spec.fn, {
      desc = spec.desc,
      nargs = spec.nargs or 0,
    })
  end

  -- ─── autocmds ────────────────────────────────────────────────────────────

  local aug = vim.api.nvim_create_augroup("GoDebugConfig", { clear = true })

  -- Re-place breakpoint signs when a Go file is opened/re-loaded
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
    group = aug,
    pattern = "*.go",
    callback = function()
      local bps = dbg.list_breakpoints()
      ui.render_breakpoint_signs(bps)
    end,
  })

  -- Auto-close UI when the last non-debug window closes
  vim.api.nvim_create_autocmd("WinClosed", {
    group = aug,
    callback = function(ev)
      -- If the closed window was one of ours, tidy up state
      local closed = tonumber(ev.match)
      if not closed then
        return
      end
      -- If no non-debug editing windows remain, close the whole UI
      local have_editor = false
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if w ~= closed then
          local b = vim.api.nvim_win_get_buf(w)
          local ft = vim.bo[b].filetype
          if ft ~= "godebug" and ft ~= "" then
            have_editor = true
            break
          end
        end
      end
      if not have_editor then
        vim.schedule(ui.close)
      end
    end,
  })

  -- On VimLeavePre: kill any running dlv process cleanly
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = aug,
    once = true,
    callback = function()
      pcall(dbg.stop)
    end,
  })
end

return M
