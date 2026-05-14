-- plugin/go_debugger.lua
-- Source this or add to your Neovim config.
-- Provides keymap setup via require("go_debugger").setup(opts)

local M = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", { prefix = "<leader>d" }, opts or {})
  local p = opts.prefix

  local function map(mode, suffix, cmd, desc, extra)
    vim.keymap.set(mode, p .. suffix, cmd,
      vim.tbl_extend("force", { silent = true, desc = "[go-debug] " .. desc }, extra or {}))
  end

  -- ── session-scoped arrow keys ──────────────────────────────────────────────
  local session_keys = {}

  local function install_session_keys()
    local function sm(lhs, cmd, desc)
      table.insert(session_keys, lhs)
      vim.keymap.set("n", lhs, cmd, { silent = true, desc = "[dbg] " .. desc })
    end
    sm("<F5>",   ":GoDlvContinue<CR>",  "continue")
    sm("<F10>",  ":GoDlvNext<CR>",      "step over")
    sm("<F11>",  ":GoDlvStepIn<CR>",    "step into")
    sm("<F12>",  ":GoDlvStepOut<CR>",   "step out")
    sm("<Down>", ":GoDlvNext<CR>",      "step over")
    sm("<Right>",":GoDlvStepIn<CR>",    "step into")
    sm("<Left>", ":GoDlvStepOut<CR>",   "step out")
    sm("<Up>",   ":GoDlvContinue<CR>",  "continue")
  end

  local function remove_session_keys()
    for _, lhs in ipairs(session_keys) do
      pcall(vim.keymap.del, "n", lhs)
    end
    session_keys = {}
  end

  -- ── launch ────────────────────────────────────────────────────────────────

  map("n", "d", function() install_session_keys(); vim.cmd("GoDlvDebug") end,      "debug main package")
  map("n", "t", function() install_session_keys(); vim.cmd("GoDlvTest") end,       "debug test package")
  map("n", "b", function() install_session_keys(); vim.cmd("GoDlvAttachSpawn") end,"build + debug binary")
  map("n", "a", function()
    install_session_keys()
    vim.ui.input({ prompt = "PID: " }, function(v)
      if v and v ~= "" then vim.cmd("GoDlvAttach " .. v) end
    end)
  end, "attach to pid")
  map("n", "C", function()
    install_session_keys()
    vim.ui.input({ prompt = "Connect (host:port): " }, function(v)
      if v and v ~= "" then vim.cmd("GoDlvConnect " .. v) end
    end)
  end, "connect to headless dlv")
  map("n", "r", function() install_session_keys(); vim.cmd("GoDlvRestart") end,    "restart session")
  map("n", "q", function() remove_session_keys(); vim.cmd("GoDlvStop") end,        "stop session")

  -- ── execution ─────────────────────────────────────────────────────────────

  map("n", "c", ":GoDlvContinue<CR>",    "continue")
  map("n", "n", ":GoDlvNext<CR>",        "step over")
  map("n", "s", ":GoDlvStepIn<CR>",      "step into")
  map("n", "o", ":GoDlvStepOut<CR>",     "step out")
  map("n", "z", ":GoDlvPause<CR>",       "pause")
  map("n", "g", ":GoDlvRunToCursor<CR>", "run to cursor")

  -- ── breakpoints ───────────────────────────────────────────────────────────

  map("n", "p", ":GoDlvBreakpoint<CR>",      "toggle breakpoint")
  map("n", "P", ":GoDlvCondBreakpoint<CR>",  "conditional breakpoint")
  map("n", "L", ":GoDlvLogpoint<CR>",        "logpoint")
  map("n", "H", ":GoDlvHitBreakpoint<CR>",   "hit-count breakpoint")
  map("n", "x", ":GoDlvRemoveBreakpoint<CR>","remove breakpoint")
  map("n", "X", ":GoDlvClearBreakpoints<CR>","clear all breakpoints")

  -- ── inspection ────────────────────────────────────────────────────────────

  map("n", "k", ":GoDlvHover<CR>", "hover eval")
  map("v", "k", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
    local expr  = vim.trim(table.concat(lines, " "))
    vim.cmd("GoDlvHover " .. vim.fn.escape(expr, " "))
  end, "hover eval selection")
  map("n", "e", ":GoDlvInspect<CR>",  "inspect expression")
  map("n", "E", ":GoDlvSetVar<CR>",   "set variable")

  -- ── watches ───────────────────────────────────────────────────────────────

  map("n", "w", ":GoDlvWatchAdd<CR>",    "add watch")
  map("v", "w", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
    local expr  = vim.trim(table.concat(lines, " "))
    vim.cmd("GoDlvWatchAdd " .. vim.fn.escape(expr, " "))
  end, "watch selection")
  map("n", "W", ":GoDlvWatchRemove<CR>", "remove watch")

  -- ── UI ────────────────────────────────────────────────────────────────────

  map("n", "u", ":GoDlvUI<CR>", "toggle debug UI")
  map("n", "V", ":GoDlvToggleVirt<CR>", "toggle virtual text")

  -- ── autocmds ──────────────────────────────────────────────────────────────

  local aug = vim.api.nvim_create_augroup("GoDebugConfig", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = aug, once = true,
    callback = function() pcall(vim.cmd, "GoDlvStop") end,
  })
end

return M
