--------------------------------------------------------------------------------
-- custom/terminal_manager/init.lua  v5
-- require("custom.terminal_manager")
--
-- NEW IN v5
--   • Panel hide / show (jobs survive, <leader>zh / H in sidebar)
--   • Side-by-side split panes (<leader>z| / s in sidebar)
--   • Search within terminal (<C-f> in terminal, :TerminalSearch)
--   • Link + file:line detection (gx / gf / gl in terminal normal mode)
--   • Virtual-environment detection (Python venv/conda/poetry/pipenv,
--     Node nvm, Ruby rbenv/bundler, Go modules, Rust cargo)
--   • Venv badge in sidebar + winbar
--   • Module path: custom.terminal_manager
--
-- LAYOUT (normal)                    LAYOUT (split)
--   [sidebar | term_win]               [sidebar | term_win | term_win2]
--
-- KEYMAPS (sidebar)
--   <CR>           select terminal     s          toggle split
--   j/k            navigate            H          hide panel
--   n              new terminal        P          profile manager
--   f              float selected term
--   d/r/R          del/rename/restart  ?          toggle help
--   <Tab>          focus/cycle panes   q          close panel
--
-- KEYMAPS (global, normal mode)
--   <leader>zt     toggle panel        <leader>z|   toggle split
--   <leader>zh     hide panel          <leader>z<   focus pane 1
--   <leader>zf     toggle float mode
--   <leader>zn     new terminal        <leader>z>   focus pane 2
--   <leader>zT     focus sidebar       <leader>zx   swap panes
--   <leader>zp     pick profile        <leader>z1-9 jump to #N
--   <leader>zP     profile manager
--
-- KEYMAPS (terminal, insert mode)
--   <Esc><Esc>     normal mode         <C-f>  search in terminal
--   <C-h/j/k/l>   navigate windows
--
-- KEYMAPS (terminal, normal mode)
--   <C-f>  search    gx/gf  open link/file:line    gl  list links
--
-- COMMANDS
--   :TerminalNew [name]   :TerminalProfiles   :TerminalProfileNew
--   :TerminalAutomation   :TerminalSplit       :TerminalHide
--   :TerminalSearch       :TerminalFloat       :TerminalPanel
--
-- MODULES
--   init.lua            entry point
--   config.lua          default configuration
--   state.lua           shared mutable state
--   highlights.lua      highlight group definitions
--   utils.lua           pure helpers + pane utilities
--   profiles.lua        profile lookup / cmd / env / keymap registration
--   profile_store.lua   JSON persistence (~/.local/share/nvim/terminal_manager/)
--   profile_wizard.lua  interactive profile creation wizard
--   profile_manager.lua browse / create / edit / delete profiles
--   panel.lua           layout builder (normal + split)
--   sidebar.lua         render + action handlers
--   help.lua            floating help window
--   winbar.lua          winbar for primary + secondary panes
--   terminal.lua        spawn + restart + venv inject + link attach
--   split.lua           second terminal pane management
--   search.lua          floating search-within-terminal UI
--   links.lua           URL + file:line detection / navigation
--   venv.lua            virtual environment detection
--   api.lua             public API
--   autocmds.lua        plugin autocommands
--   keymaps.lua         global keymaps + :Terminal* commands
--------------------------------------------------------------------------------

local M = {}

M.config = require("custom.terminal_manager.config").values

local highlights = require("custom.terminal_manager.highlights")
highlights.setup()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("TermManagerHL", { clear = true }),
  callback = highlights.setup,
})

local api = require("custom.terminal_manager.api")
M.open = api.open
M.close = api.close
M.hide = api.hide
M.show = api.show
M.toggle = api.toggle
M.set_mode = api.set_mode
M.toggle_mode = api.toggle_mode
M.new_term = api.new_term
M.new_automation_term = api.new_automation_term
M.delete_term = api.delete_term
M.focus_sidebar = api.focus_sidebar
M.pick_profile = api.pick_profile
M.show_profiles = api.show_profiles
M._send_lines = api._send_lines
M.send_selection = api.send_selection

require("custom.terminal_manager.autocmds").setup()
require("custom.terminal_manager.keymaps").setup()

vim.schedule(function()
  require("custom.terminal_manager.profile_store").merge_into_config()
  require("custom.terminal_manager.profiles").validate_profiles()
end)

return M
