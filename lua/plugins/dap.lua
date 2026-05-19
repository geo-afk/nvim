-- lua/plugins/dap.lua
-- nvim-dap configuration using vim.pack (Neovim 0.12+)
-- Stack: Go · Node.js · TypeScript · Angular · Windows

-- ---------------------------------------------------------------------------
-- 1. Packages
-- ---------------------------------------------------------------------------
vim.pack.add({
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/rcarriga/nvim-dap-ui" },
  { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
  { src = "https://github.com/leoluz/nvim-dap-go" },
  { src = "https://github.com/mxsdev/nvim-dap-vscode-js" },
  { src = "https://github.com/nvim-telescope/telescope-dap.nvim" },
})

local ok, dap = pcall(require, "dap")
if not ok then
  vim.notify("[dap] nvim-dap not loaded – run :PackUpdate and restart.", vim.log.levels.WARN)
  return
end

-- ---------------------------------------------------------------------------
-- 2. Signs & highlights
-- ---------------------------------------------------------------------------
require("dap.signs").setup()

-- ---------------------------------------------------------------------------
-- 3. Adapter + configuration modules
-- ---------------------------------------------------------------------------
require("dap.go")
require("dap.node")
require("dap.angular")

-- ---------------------------------------------------------------------------
-- 4. .vscode/launch.json auto-loader
-- ---------------------------------------------------------------------------
require("dap.vscode").setup()

-- ---------------------------------------------------------------------------
-- 5. nvim-dap-ui
-- ---------------------------------------------------------------------------
local ui_ok, dapui = pcall(require, "dapui")
if ui_ok then
  dapui.setup({
    icons = { expanded = "▾", collapsed = "▸", current_frame = "→" },
    mappings = {
      expand    = { "<CR>", "<2-LeftMouse>" },
      open      = "o",
      remove    = "d",
      edit      = "e",
      repl      = "r",
      toggle    = "t",
    },
    expand_lines  = true,
    force_buffers = true,
    layouts = {
      {
        elements = {
          { id = "scopes",      size = 0.40 },
          { id = "breakpoints", size = 0.15 },
          { id = "stacks",      size = 0.25 },
          { id = "watches",     size = 0.20 },
        },
        size     = 40,
        position = "left",
      },
      {
        elements = {
          { id = "repl",    size = 0.5 },
          { id = "console", size = 0.5 },
        },
        size     = 12,
        position = "bottom",
      },
    },
    controls = {
      enabled = true,
      element = "repl",
      icons = {
        pause      = "⏸",
        play       = "▶",
        step_into  = "⬇",
        step_over  = "⮕",
        step_out   = "⬆",
        step_back  = "⬅",
        run_last   = "↺",
        terminate  = "⏹",
        disconnect = "⏏",
      },
    },
    floating = {
      max_height = 0.9,
      max_width  = 0.9,
      border     = "rounded",
      mappings   = { close = { "q", "<Esc>" } },
    },
    render = {
      max_type_length = nil,
      max_value_lines = 100,
    },
  })

  dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
  dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
  dap.listeners.before.event_exited["dapui"]     = function() dapui.close() end
end

-- ---------------------------------------------------------------------------
-- 6. nvim-dap-virtual-text
-- ---------------------------------------------------------------------------
local vt_ok, vtext = pcall(require, "nvim-dap-virtual-text")
if vt_ok then
  vtext.setup({
    enabled                     = true,
    enabled_commands            = true,
    highlight_changed_variables = true,
    highlight_new_as_changed    = false,
    show_stop_reason            = true,
    commented                   = false,
    only_first_definition       = true,
    all_references              = false,
    clear_on_continue           = false,
    display_callback = function(variable, _buf, _stackframe, _node, opts)
      if opts.virt_text_pos == "inline" then
        return " = " .. variable.value
      end
      return variable.name .. " = " .. variable.value
    end,
    virt_text_pos = "eol",
    all_frames    = false,
    virt_lines    = false,
  })
end

-- ---------------------------------------------------------------------------
-- 7. Telescope DAP pickers
-- ---------------------------------------------------------------------------
require("dap.telescope").setup()

-- ---------------------------------------------------------------------------
-- 8. Overseer integration (preLaunchTask support)
-- ---------------------------------------------------------------------------
local ov_ok, overseer = pcall(require, "overseer")
if ov_ok then overseer.enable_dap() end

-- ---------------------------------------------------------------------------
-- 9. Keymaps
-- ---------------------------------------------------------------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
end

-- Session
map("<leader>dc", dap.continue,      "DAP: Continue / start")
map("<leader>dC", dap.run_to_cursor, "DAP: Run to cursor")
map("<leader>dq", dap.terminate,     "DAP: Terminate")
map("<leader>dr", dap.restart,       "DAP: Restart")
map("<leader>dp", dap.pause,         "DAP: Pause")
map("<leader>dl", dap.run_last,      "DAP: Run last")

-- Stepping
map("<leader>dn", dap.step_over, "DAP: Step over")
map("<leader>di", dap.step_into, "DAP: Step into")
map("<leader>do", dap.step_out,  "DAP: Step out")
map("<leader>db", dap.step_back, "DAP: Step back")

-- Breakpoints
map("<leader>dB", dap.toggle_breakpoint, "DAP: Toggle breakpoint")
map("<leader>dX", dap.clear_breakpoints, "DAP: Clear all breakpoints")
map("<leader>dE", function()
  dap.set_breakpoint(vim.fn.input("Condition: "))
end, "DAP: Conditional breakpoint")
map("<leader>dL", function()
  dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
end, "DAP: Log point")

-- Inspection
local widgets = require("dap.ui.widgets")
map("<leader>dh", widgets.hover, "DAP: Hover variable")
map("<leader>dv", function() widgets.centered_float(widgets.scopes) end, "DAP: Scopes float")
map("<leader>df", function() widgets.centered_float(widgets.frames) end, "DAP: Frames float")

-- REPL
map("<leader>dR", function() dap.repl.toggle({}, "belowright split") end, "DAP: Toggle REPL")

-- UI
if ui_ok then
  map("<leader>du", dapui.toggle, "DAP: Toggle UI")
  map("<leader>de", dapui.eval,   "DAP: Eval expression")
  vim.keymap.set("v", "<leader>de", dapui.eval,
    { noremap = true, silent = true, desc = "DAP: Eval selection" })
end

-- ---------------------------------------------------------------------------
-- 10. User commands
-- ---------------------------------------------------------------------------
local cmd = vim.api.nvim_create_user_command

cmd("DapContinue",  function() dap.continue() end,         { desc = "DAP: Continue" })
cmd("DapTerminate", function() dap.terminate() end,         { desc = "DAP: Terminate" })
cmd("DapRestart",   function() dap.restart() end,           { desc = "DAP: Restart" })
cmd("DapStepOver",  function() dap.step_over() end,         { desc = "DAP: Step over" })
cmd("DapStepInto",  function() dap.step_into() end,         { desc = "DAP: Step into" })
cmd("DapStepOut",   function() dap.step_out() end,          { desc = "DAP: Step out" })
cmd("DapRunLast",   function() dap.run_last() end,          { desc = "DAP: Run last" })
cmd("DapBreakpoint",function() dap.toggle_breakpoint() end, { desc = "DAP: Toggle breakpoint" })
cmd("DapClearBreakpoints", function() dap.clear_breakpoints() end, { desc = "DAP: Clear all" })

cmd("DapConditional", function()
  dap.set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "DAP: Conditional breakpoint" })

cmd("DapLogPoint", function()
  dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
end, { desc = "DAP: Log point" })

cmd("DapListBreakpoints", function()
  dap.list_breakpoints()
  vim.cmd("copen")
end, { desc = "DAP: Breakpoints → quickfix" })

cmd("DapLoadVSCode", function()
  local root = vim.fs.root(vim.fn.expand("%:p:h"), { ".vscode" }) or vim.fn.getcwd()
  require("dap.vscode").load(root)
end, { desc = "DAP: (Re)load .vscode/launch.json" })

-- ---------------------------------------------------------------------------
-- 11. Which-key documentation
-- ---------------------------------------------------------------------------
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.add({
    { "<leader>d", group = "Debug" },
    { "<leader>dg", group = "Go" },
    { "<leader>da", group = "Angular" },
    { "<leader>dt", group = "Telescope" },
  })
end

