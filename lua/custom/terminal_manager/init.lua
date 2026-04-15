--------------------------------------------------------------------------------
-- custom.terminal_manager/init.lua  v3 (modular)
-- VS Code-style multi-terminal panel for Neovim >= 0.10
--
-- Layout:
--   ┌────────────────────────────────────────────────────────────┐
--   │                    editor windows                          │
--   ├──────────────────────┬─────────────────────────────────────┤
--   │  ▌ TERMINALS (2)     │ ● $ terminal 1  [Default]   <...>  │
--   │                      │                                     │
--   │  ▶ ● $ terminal 1   │   active terminal output            │
--   │    ● ~ python repl  │                                     │
--   │    ○ $ terminal 3   │                                     │
--   │  ────────────────    │                                     │
--   │    + new terminal    │                                     │
--   │    ? help            │                                     │
--   └──────────────────────┴─────────────────────────────────────┘
--
-- Sidebar keys:
--   <CR> / <2-LeftMouse>   select terminal (auto-restarts if dead)
--   j / k                  navigate list (clamped to terminal rows)
--   n                      new terminal → profile picker → name prompt
--   d                      delete terminal under cursor
--   r                      rename terminal under cursor
--   R                      force-restart terminal under cursor
--   <Tab>                  focus the terminal pane (starts insert mode)
--   q                      close the panel
--   ?                      toggle help float
--
-- Terminal — terminal-mode keys (applied to every non-plugin terminal):
--   <Esc><Esc>             exit to normal mode
--   <C-h/j/k/l>           navigate Neovim windows
--
-- Terminal — normal-mode keys:
--   <leader>zT             focus sidebar
--
-- Global — normal mode:
--   <leader>zt             toggle panel
--   <leader>zn             new terminal
--   <leader>zT             focus sidebar
--   <leader>zp             pick profile for new terminal
--   <leader>z1-9           jump to terminal N
--
-- Visual mode:
--   <leader>zs             send selection to active terminal
--
-- User commands:
--   :TerminalNew [name]           open a managed terminal
--   :TerminalProfiles             show configured profiles
--   :TerminalAutomation [name]    open terminal with automation profile
--
-- Configuration (override after require):
--   local tm = require("custom.terminal_manager")
--   tm.config.sidebar_width = 30
--   tm.config.profiles = {
--     { name = "zsh", shell = "zsh", args = {"-l"}, icon = "%", color = "green" },
--   }
--
-- Module structure:
--   init.lua       ← you are here (public M table + wiring)
--   config.lua     default config values
--   state.lua      shared mutable state (terminals[], ui{}, etc.)
--   highlights.lua highlight group definitions
--   utils.lua      pure helpers (buf_ok, win_ok, term_alive, …)
--   profiles.lua   profile lookup, validation, cmd/env builders
--   panel.lua      layout builder (build_panel + ensure)
--   sidebar.lua    render_sidebar + sidebar action handlers
--   help.lua       floating help window
--   winbar.lua     update_winbar
--   terminal.lua   spawn_in_term_win + show_terminal + restart
--   api.lua        public API (open/close/toggle/new_term/delete_term/…)
--   autocmds.lua   plugin autocommands
--   keymaps.lua    global keymaps + :Terminal* user commands
--------------------------------------------------------------------------------

local M = {}

-- ── Configuration ─────────────────────────────────────────────────────────────
-- Initialised from defaults; users mutate M.config directly after require().
M.config = vim.deepcopy(require("custom.terminal_manager.config").defaults)

-- ── Highlight groups ──────────────────────────────────────────────────────────
local highlights = require("custom.terminal_manager.highlights")
highlights.setup()

-- Re-apply after :colorscheme so linked groups are recalculated.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("TermManagerHL", { clear = true }),
  callback = highlights.setup,
})

-- ── Public API ─────────────────────────────────────────────────────────────────
-- Proxy every api.lua function onto M so callers can do:
--   require("custom.terminal_manager").toggle()
local api = require("custom.terminal_manager.api")
M.open = api.open
M.close = api.close
M.toggle = api.toggle
M.new_term = api.new_term
M.new_automation_term = api.new_automation_term
M.delete_term = api.delete_term
M.focus_sidebar = api.focus_sidebar
M.pick_profile = api.pick_profile
M.show_profiles = api.show_profiles
M._send_lines = api._send_lines
M.send_selection = api.send_selection

-- ── Autocommands & keymaps ────────────────────────────────────────────────────
require("custom.terminal_manager.autocmds").setup()
require("custom.terminal_manager.keymaps").setup()

-- ── Startup validation ────────────────────────────────────────────────────────
-- Deferred so Neovim is fully initialised before we probe executables.
vim.schedule(function()
  require("custom.terminal_manager.profiles").validate_profiles()
end)

return M
