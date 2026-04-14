--------------------------------------------------------------------------------
-- terminal_manager.lua  v2
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
--   <leader>z1-9           jump to terminal N
--
-- Visual mode:
--   <leader>zs             send selection to active terminal
--
-- Configuration (override before / after require):
--   local tm = require("terminal_manager")
--   tm.config.sidebar_width = 30
--   tm.config.profiles = {
--     { name = "zsh", shell = "zsh", args = {"-l"}, icon = "%", color = "green" },
--   }
--------------------------------------------------------------------------------

local M = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
M.config = {
  -- Panel dimensions
  sidebar_width = 26,
  panel_height = 0.33, -- fraction of total screen lines
  min_panel_lines = 6, -- hard minimum (lines)
  max_panel_frac = 0.60, -- hard maximum (fraction)

  -- Default shell for profiles that set shell = nil.
  shell = nil, -- nil → vim.o.shell
  inherit_env = true,
  default_profile = "Default",
  automation_profile = nil,

  -- Terminal profiles – mirror of VS Code's terminal.integrated.profiles.*
  --
  -- Available fields per profile:
  --   name          string    Display name (required)
  --   shell         string|nil  Executable; nil → vim.o.shell
  --   args          string[]    Extra arguments for the shell
  --   env           table       Additional env variables: { VAR = "value" }
  --                             Set a variable to false to remove it.
  --   cwd           string|nil  Working directory; nil → current pwd
  --   icon          string      Single char shown in sidebar + winbar
  --   color         string      Accent colour: blue green red yellow cyan
  --                                            magenta orange white
  --   override_name bool        Reserved – keep profile name as terminal title
  --
  -- When only one profile is defined, the picker is skipped on new_term().
  profiles = {
    {
      name = "Default",
      shell = nil,
      args = {},
      env = {},
      cwd = nil,
      icon = "$",
      color = "blue",
      override_name = false,
    },
    -- Uncomment or add your own profiles:
    -- { name = "bash",   shell = "bash",    args = {},        icon = "$", color = "blue"    },
    -- { name = "zsh",    shell = "zsh",     args = {"-l"},    icon = "%", color = "green"   },
    -- { name = "fish",   shell = "fish",    args = {},        icon = ">", color = "cyan"    },
    -- { name = "Python", shell = "python3", args = {"-i"},    icon = "~", color = "yellow"  },
    -- { name = "Node",   shell = "node",    args = {},        icon = ">", color = "green"   },
    -- { name = "nushell",shell = "nu",      args = {},        icon = ">", color = "magenta" },
  },

  -- Buffers whose names contain any of these strings skip terminal keymaps.
  skip_patterns = { "fzf", "claude", "lazygit" },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
-- Each entry: { id:int, name:string, buf:int|nil, profile:table }
local terminals = {}
local next_id = 1
local active_id = nil -- id of the terminal currently shown in ui.term_win

local ui = {
  sidebar_buf = nil,
  sidebar_win = nil,
  term_win = nil,
}

-- Populated by render_sidebar(); consumed by action handlers.
local sidebar_meta = { term_rows = {}, new_row = nil, help_row = nil }

local ns = vim.api.nvim_create_namespace("TermManager")

-- Forward declaration: show_terminal() needs to call build_panel().
local build_panel

--------------------------------------------------------------------------------
-- Highlight groups
-- All use default = true so a colorscheme or the user's init.lua can override.
--------------------------------------------------------------------------------
local function setup_highlights()
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", opts, { default = true }))
  end

  -- Sidebar chrome
  hl("TermManagerHeader", { link = "Title" }) -- "▌ TERMINALS" line
  hl("TermManagerSep", { link = "FloatBorder" }) -- separator lines
  hl("TermManagerNew", { link = "SpecialKey" }) -- "+" glyph
  hl("TermManagerHelpHint", { link = "Comment" }) -- "?" glyph

  -- Terminal entry states (whole-line)
  hl("TermManagerActive", { link = "PmenuSel" }) -- active terminal row
  hl("TermManagerAlive", { link = "Normal" }) -- running, not active
  hl("TermManagerDead", { link = "Comment" }) -- shell exited
  hl("TermManagerPlaceholder", { link = "Comment" }) -- "(no terminals)" text

  -- Glyph-level highlights (applied over the full-line hl)
  hl("TermManagerArrow", { link = "DiagnosticOk" }) -- ▶ on active row

  -- Winbar
  hl("TermManagerWinbarDot", { link = "DiagnosticOk" })
  hl("TermManagerWinbar", { link = "WinBar" })
  hl("TermManagerWinbarHint", { link = "Comment" })

  -- Profile accent colours for the status dot (● / ○).
  -- Kept separate so the dot stands out even inside a PmenuSel row.
  local accent = {
    Blue = "DiagnosticInfo",
    Green = "DiagnosticOk",
    Red = "DiagnosticError",
    Yellow = "DiagnosticWarn",
    Cyan = "DiagnosticHint",
    Magenta = "Special",
    Orange = "WarningMsg",
    White = "Normal",
  }
  for cap, target in pairs(accent) do
    hl("TermManagerAccent" .. cap, { link = target })
  end
end

setup_highlights()

-- Re-apply after :colorscheme so links are recalculated.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("TermManagerHL", { clear = true }),
  callback = setup_highlights,
})

--- Map a profile color string to its highlight group name.
local function accent_hl(color)
  local c = tostring(color or "blue")
  return "TermManagerAccent" .. c:sub(1, 1):upper() .. c:sub(2):lower()
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function buf_ok(b)
  return b ~= nil and vim.api.nvim_buf_is_valid(b)
end

local function win_ok(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

--- True when the terminal job inside `buf` is still running.
local function term_alive(buf)
  if not buf_ok(buf) then
    return false
  end
  local ok, chan = pcall(vim.api.nvim_get_option_value, "channel", { buf = buf })
  return ok and chan and chan > 0 and vim.fn.jobwait({ chan }, 0)[1] == -1
end

--- Find a terminal by id.  Returns (entry, 1-based index) or (nil, nil).
local function find_term(id)
  if not id then
    return nil, nil
  end
  for i, t in ipairs(terminals) do
    if t.id == id then
      return t, i
    end
  end
  return nil, nil
end

--- True when at least one panel window is valid.
local function panel_open()
  return win_ok(ui.sidebar_win) or win_ok(ui.term_win)
end

local function panel_complete()
  return win_ok(ui.sidebar_win) and win_ok(ui.term_win)
end

--- Panel height in lines, clamped between the configured bounds.
local function panel_height()
  local h = math.floor(vim.o.lines * M.config.panel_height)
  h = math.max(h, M.config.min_panel_lines)
  h = math.min(h, math.floor(vim.o.lines * M.config.max_panel_frac))
  h = math.min(h, math.max(0, vim.o.lines - 3)) -- always leave room for the editor
  return h
end

local function get_shell()
  return M.config.shell or vim.o.shell
end

local function shell_cmd_display(shell)
  if type(shell) == "table" then
    return tostring(shell[1] or "")
  end
  return tostring(shell or "")
end

local function shell_is_executable(shell)
  if type(shell) == "table" then
    shell = shell[1]
  end
  if not shell or shell == "" then
    return false
  end
  if shell:match("[/\\]") then
    return vim.uv.fs_stat(shell) ~= nil
  end
  return vim.fn.executable(shell) == 1
end

local function find_profile(name)
  if not name or name == "" then
    return nil
  end
  for _, profile in ipairs(M.config.profiles) do
    if profile.name == name then
      return profile
    end
  end
  return nil
end

local function default_profile()
  return find_profile(M.config.default_profile) or M.config.profiles[1]
end

local function automation_profile()
  return find_profile(M.config.automation_profile) or default_profile()
end

local function validate_profiles()
  for _, profile in ipairs(M.config.profiles) do
    local shell = profile.shell or get_shell()
    if shell_cmd_display(shell) ~= "" and not shell_is_executable(shell) then
      vim.schedule(function()
        vim.notify(
          ("TermManager: profile '%s' shell not found: %s"):format(profile.name, shell_cmd_display(shell)),
          vim.log.levels.WARN
        )
      end)
    end
  end
end

--- Build the shell command to pass to termopen() from a profile table.
local function profile_cmd(profile)
  profile = profile or {}
  local shell = profile.shell or get_shell()
  if type(shell) == "table" then
    return shell
  end
  if profile.args and #profile.args > 0 then
    local cmd = { shell }
    vim.list_extend(cmd, profile.args)
    return cmd
  end
  return shell
end

local function profile_env(profile)
  local extra = profile.env or {}
  if not M.config.inherit_env then
    local out = {}
    for key, value in pairs(extra) do
      if value ~= false and value ~= vim.NIL then
        out[key] = tostring(value)
      end
    end
    return out
  end

  local out = vim.fn.environ()
  for key, value in pairs(extra) do
    if value == false or value == vim.NIL then
      out[key] = nil
    else
      out[key] = tostring(value)
    end
  end
  return out
end

--- Set a window option safely (no-op if the window is gone).
local function win_opt(win, name, value)
  if not win_ok(win) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { win = win })
end

--- Set a buffer option safely (no-op if the buffer is gone).
local function buf_opt(buf, name, value)
  if not buf_ok(buf) then
    return
  end
  vim.api.nvim_set_option_value(name, value, { buf = buf })
end

local function reset_panel_handles()
  ui.sidebar_buf = nil
  ui.sidebar_win = nil
  ui.term_win = nil
end

local function ensure_panel()
  if panel_complete() then
    return true
  end

  if panel_open() then
    M.close()
  end

  local ok, err = pcall(build_panel)
  if not ok then
    vim.notify("TermManager: " .. tostring(err), vim.log.levels.WARN)
    return false
  end

  return panel_complete()
end

--------------------------------------------------------------------------------
-- Winbar
-- A one-line status header above ui.term_win using statusline %-sequences.
--------------------------------------------------------------------------------
local function update_winbar()
  if not win_ok(ui.term_win) then
    return
  end

  local t = find_term(active_id)
  if not t then
    win_opt(ui.term_win, "winbar", "")
    return
  end

  local profile = t.profile or {}
  local icon = profile.icon or "$"
  local alive = term_alive(t.buf)
  local dot = alive and "●" or "○"
  local dot_hl = alive and "TermManagerWinbarDot" or "TermManagerDead"
  local profname = profile.name or "shell"

  -- Left: dot + icon + name + profile tag
  -- Right (after %=): keyboard hints
  local bar = string.format(
    " %%#%s#%s %%#TermManagerWinbar#%s %s%%#TermManagerWinbarHint# [%s]%%*"
      .. "%%=%%#TermManagerWinbarHint# <Esc><Esc> normal  ·  <leader>zT sidebar ",
    dot_hl,
    dot,
    icon,
    t.name,
    profname
  )
  win_opt(ui.term_win, "winbar", bar)
end

--------------------------------------------------------------------------------
-- Sidebar rendering
--------------------------------------------------------------------------------

--- Rebuild sidebar buffer content and highlights.
--- Populates sidebar_meta for action handlers to consume.
local function render_sidebar()
  local buf = ui.sidebar_buf
  if not buf_ok(buf) then
    return
  end

  local w = M.config.sidebar_width
  local sep = ("─"):rep(w - 2)
  local cnt = #terminals

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  local lines = {}
  local meta = { term_rows = {}, new_row = nil, help_row = nil }
  -- Each entry: { row0, col_s, col_e, group }
  -- Less-specific (wider) highlights are added first; more-specific (narrower)
  -- ones are added after so Neovim's extmark priority resolves in our favour.
  local hls = {}

  -- Row 1: coloured title
  lines[1] = string.format("  ▌ TERMINALS (%d)", cnt)
  hls[#hls + 1] = { 0, 0, -1, "TermManagerHeader" }

  -- Row 2: blank spacer
  lines[2] = ""

  local row = 3 -- 1-based row for the next line

  -- ── Terminal list ──────────────────────────────────────────────────────────
  if cnt == 0 then
    lines[row] = "  (no terminals — press n)"
    hls[#hls + 1] = { row - 1, 0, -1, "TermManagerPlaceholder" }
    row = row + 1
  else
    for i, t in ipairs(terminals) do
      meta.term_rows[row] = i

      local alive = term_alive(t.buf)
      local active = (t.id == active_id)
      local arrow = active and "▶" or " "
      local dot = alive and "●" or "○"
      local icon = (t.profile and t.profile.icon) or "$"

      -- Truncate the name so the line fits inside the sidebar window.
      -- Fixed prefix: indent(2) + arrow(1) + sp(1) + dot(1) + sp(1) + icon(1) + sp(1) = 8
      local max_name = math.max(1, w - 8)
      local name = t.name
      if #name > max_name then
        name = name:sub(1, max_name - 1) .. "…"
      end

      lines[row] = string.format("  %s %s %s %s", arrow, dot, icon, name)

      -- ① Full-line state highlight
      local line_hl = active and "TermManagerActive" or alive and "TermManagerAlive" or "TermManagerDead"
      hls[#hls + 1] = { row - 1, 0, -1, line_hl }

      -- ② Arrow glyph highlight (only for the active entry).
      --    "▶" is 3 UTF-8 bytes starting at byte offset 2.
      if active then
        hls[#hls + 1] = { row - 1, 2, 5, "TermManagerArrow" }
      end

      -- ③ Dot glyph highlight (profile accent colour).
      --    "●"/"○" = 3 UTF-8 bytes each.
      --    Byte layout of the formatted line:
      --      active   "  ▶ ●…" → indent(2) + ▶(3) + sp(1) = dot at byte 6
      --      inactive "    ●…" → indent(2) + sp(1) + sp(1) = dot at byte 4
      local dot_col = active and 6 or 4
      local dot_hl = alive and accent_hl((t.profile or {}).color) or "TermManagerDead"
      hls[#hls + 1] = { row - 1, dot_col, dot_col + 3, dot_hl }

      row = row + 1
    end
  end

  -- ── Footer ─────────────────────────────────────────────────────────────────
  lines[row] = ""
  row = row + 1

  lines[row] = "  " .. sep
  hls[#hls + 1] = { row - 1, 0, -1, "TermManagerSep" }
  row = row + 1

  meta.new_row = row
  lines[row] = "  + new terminal"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerNew" }
  row = row + 1

  meta.help_row = row
  lines[row] = "  ? help"
  hls[#hls + 1] = { row - 1, 2, 3, "TermManagerHelpHint" }

  -- ── Commit ─────────────────────────────────────────────────────────────────
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(buf, ns, h[4], h[1], h[2], h[3])
  end

  sidebar_meta = meta

  -- Move the sidebar cursor to the active terminal's row.
  if win_ok(ui.sidebar_win) and active_id then
    for r, i in pairs(meta.term_rows) do
      if terminals[i] and terminals[i].id == active_id then
        pcall(vim.api.nvim_win_set_cursor, ui.sidebar_win, { r, 0 })
        break
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Help floating window
--------------------------------------------------------------------------------
local help_win_h = nil -- handle; allows toggling the window with the same key

local function open_help()
  -- Toggle: close if already open.
  if win_ok(help_win_h) then
    pcall(vim.api.nvim_win_close, help_win_h, true)
    help_win_h = nil
    return
  end

  local lines = {
    "",
    "   Terminal Manager — Help   ",
    "",
    "  Sidebar",
    "  ───────────────────────────",
    "  <CR>        select / restart",
    "  j / k       navigate list",
    "  n           new terminal",
    "  d           delete terminal",
    "  r           rename terminal",
    "  R           restart terminal",
    "  <Tab>       focus terminal",
    "  q           close panel",
    "  ?           toggle this help",
    "",
    "  Terminal — insert mode",
    "  ───────────────────────────",
    "  <Esc><Esc>    normal mode",
    "  <C-h/j/k/l>  nav windows",
    "",
    "  Terminal — normal mode",
    "  ───────────────────────────",
    "  <leader>zT   sidebar",
    "",
    "  Global — normal mode",
    "  ───────────────────────────",
    "  <leader>zt    toggle panel",
    "  <leader>zn    new terminal",
    "  <leader>zT    focus sidebar",
    "  <leader>z1-9  jump to N",
    "",
    "  Visual mode",
    "  ───────────────────────────",
    "  <leader>zs  send selection",
    "",
    "  q / <Esc>  close",
    "",
  }

  local width = 34
  local height = math.min(#lines, vim.o.lines - 4)

  local hbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
  buf_opt(hbuf, "modifiable", false)

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local hwin = vim.api.nvim_open_win(hbuf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
    noautocmd = true,
  })
  help_win_h = hwin

  pcall(win_opt, hwin, "winblend", 8)
  pcall(win_opt, hwin, "cursorline", false)
  pcall(win_opt, hwin, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  -- Syntax highlights inside the help buffer.
  local hns = vim.api.nvim_create_namespace("TermManagerHelpHL")
  for i, line in ipairs(lines) do
    local r0 = i - 1
    if line:match("^   Terminal Manager") then
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  %a") and not line:match("^  <") then
      -- Section headings
      vim.api.nvim_buf_add_highlight(hbuf, hns, "Title", r0, 0, -1)
    elseif line:match("^  ─") then
      vim.api.nvim_buf_add_highlight(hbuf, hns, "FloatBorder", r0, 0, -1)
    elseif line:match("^  <%S") or line:match("^  %a+%+") then
      -- Key binding lines: highlight the key token in SpecialKey
      local key_end = (line:find("%s%s") or (#line + 1)) - 1
      vim.api.nvim_buf_add_highlight(hbuf, hns, "SpecialKey", r0, 2, key_end)
    end
  end

  local function close_help()
    pcall(vim.api.nvim_win_close, hwin, true)
    pcall(vim.api.nvim_buf_delete, hbuf, { force = true })
    if help_win_h == hwin then
      help_win_h = nil
    end
  end
  local ko = { buffer = hbuf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_help, ko)
  vim.keymap.set("n", "<Esc>", close_help, ko)
  vim.keymap.set("n", "?", close_help, ko)

  -- Auto-close when focus moves away (e.g. user clicks the sidebar).
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = hbuf,
    once = true,
    callback = close_help,
  })
end

--------------------------------------------------------------------------------
-- Terminal spawn / display
--------------------------------------------------------------------------------

--- Launch a shell inside ui.term_win.  t.buf must already be set as the
--- window's buffer before this is called.
local function spawn_in_term_win(t)
  if not win_ok(ui.term_win) then
    return
  end

  local profile = t.profile or {}
  local cmd = profile_cmd(profile)
  local env = profile_env(profile)
  local cwd = profile.cwd or vim.fn.getcwd()

  vim.api.nvim_win_call(ui.term_win, function()
    -- termopen() converts the current buffer into a terminal buffer in-place.
    vim.fn.termopen(cmd, {
      env = env,
      cwd = cwd,
      on_exit = function()
        vim.schedule(function()
          render_sidebar()
          update_winbar()
        end)
      end,
    })
  end)
end

--- Make terminal `t` the visible one in ui.term_win.
--- Reopens / rebuilds the panel if it has been closed.
--- If the terminal's shell has exited, a new shell is spawned.
local function show_terminal(t)
  if not t then
    return
  end

  if not ensure_panel() then
    return
  end

  active_id = t.id

  -- Lazily create the underlying buffer on first use.
  if not buf_ok(t.buf) then
    t.buf = vim.api.nvim_create_buf(false, false)
    -- Prevent Neovim from unloading the buffer when we switch away.
    buf_opt(t.buf, "bufhidden", "hide")
  end

  vim.api.nvim_win_set_buf(ui.term_win, t.buf)

  -- Spawn the shell only when it is not already running.
  if not term_alive(t.buf) then
    spawn_in_term_win(t)
  end

  render_sidebar()
  update_winbar()

  if win_ok(ui.term_win) then
    vim.api.nvim_set_current_win(ui.term_win)
    vim.cmd("startinsert")
  end
end

--------------------------------------------------------------------------------
-- Sidebar action handlers
--------------------------------------------------------------------------------

--- Return the terminals[] index for the row under the sidebar cursor, or nil.
local function cursor_term_idx()
  if not win_ok(ui.sidebar_win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(ui.sidebar_win)[1]
  return sidebar_meta.term_rows[row]
end

local function sidebar_select()
  local idx = cursor_term_idx()
  if idx then
    show_terminal(terminals[idx])
    return
  end
  if not win_ok(ui.sidebar_win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(ui.sidebar_win)[1]
  if row == sidebar_meta.new_row then
    M.new_term()
  end
  if row == sidebar_meta.help_row then
    open_help()
  end
end

local function sidebar_delete()
  local idx = cursor_term_idx()
  if idx then
    M.delete_term(terminals[idx].id)
  end
end

local function sidebar_rename()
  local idx = cursor_term_idx()
  if not idx then
    return
  end
  local t = terminals[idx]
  vim.ui.input({ prompt = "Rename: ", default = t.name }, function(name)
    vim.schedule(function()
      if name and name ~= "" then
        t.name = name
        render_sidebar()
        update_winbar()
      end
    end)
  end)
end

--- Kill the existing shell (if any) and start a fresh one in the same slot.
local function do_restart(t)
  if buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  t.buf = nil
  show_terminal(t)
end

local function sidebar_restart()
  local idx = cursor_term_idx()
  if idx then
    do_restart(terminals[idx])
  end
end

--- Move the sidebar cursor up (delta = -1) or down (delta = +1),
--- constrained to the terminal-list rows only.
local function sidebar_move(delta)
  if not win_ok(ui.sidebar_win) then
    return
  end
  local rows = {}
  for r in pairs(sidebar_meta.term_rows) do
    rows[#rows + 1] = r
  end
  if #rows == 0 then
    return
  end
  table.sort(rows)

  local cur = vim.api.nvim_win_get_cursor(ui.sidebar_win)[1]
  local pos = 1
  for i, r in ipairs(rows) do
    if r == cur then
      pos = i
      break
    end
    if r > cur then
      pos = i
      break
    end
  end
  local new_pos = math.max(1, math.min(#rows, pos + delta))
  vim.api.nvim_win_set_cursor(ui.sidebar_win, { rows[new_pos], 0 })
end

--------------------------------------------------------------------------------
-- Panel layout builder
--------------------------------------------------------------------------------
build_panel = function()
  local h = panel_height()
  if h < 1 then
    error("not enough screen space to open the terminal panel")
  end

  -- 1. Full-width horizontal split pinned to the bottom.
  vim.cmd("botright " .. h .. "split")
  local right_win = vim.api.nvim_get_current_win()

  -- 2. Narrow sidebar split on the LEFT of that new window.
  --    After `leftabove vsplit` the left window (sidebar) is current.
  local sw = M.config.sidebar_width
  vim.cmd("leftabove " .. sw .. "vsplit")
  ui.sidebar_win = vim.api.nvim_get_current_win()
  ui.term_win = right_win

  -- 3. Sidebar scratch buffer.
  ui.sidebar_buf = vim.api.nvim_create_buf(false, true)
  buf_opt(ui.sidebar_buf, "filetype", "TermManagerSidebar")
  vim.api.nvim_win_set_buf(ui.sidebar_win, ui.sidebar_buf)

  -- 4. Sidebar window appearance.
  win_opt(ui.sidebar_win, "number", false)
  win_opt(ui.sidebar_win, "relativenumber", false)
  win_opt(ui.sidebar_win, "signcolumn", "no")
  win_opt(ui.sidebar_win, "wrap", false)
  win_opt(ui.sidebar_win, "cursorline", true)
  win_opt(
    ui.sidebar_win,
    "winhighlight",
    "Normal:NormalFloat,CursorLine:Visual,SignColumn:NormalFloat,FloatBorder:FloatBorder"
  )

  -- 5. Terminal window appearance (no decorations – let the shell breathe).
  win_opt(ui.term_win, "number", false)
  win_opt(ui.term_win, "relativenumber", false)
  win_opt(ui.term_win, "signcolumn", "no")

  -- 6. Buffer-local sidebar keymaps (automatically cleared with the buffer).
  local sb = ui.sidebar_buf
  local opt = function(desc)
    return { buffer = sb, nowait = true, silent = true, desc = desc }
  end

  vim.keymap.set("n", "<CR>", sidebar_select, opt("select / restart"))
  vim.keymap.set("n", "<2-LeftMouse>", sidebar_select, opt("select terminal"))
  vim.keymap.set("n", "j", function()
    sidebar_move(1)
  end, opt("next entry"))
  vim.keymap.set("n", "k", function()
    sidebar_move(-1)
  end, opt("prev entry"))
  vim.keymap.set("n", "n", function()
    M.new_term()
  end, opt("new terminal"))
  vim.keymap.set("n", "d", sidebar_delete, opt("delete terminal"))
  vim.keymap.set("n", "r", sidebar_rename, opt("rename terminal"))
  vim.keymap.set("n", "R", sidebar_restart, opt("restart terminal"))
  vim.keymap.set("n", "q", function()
    M.close()
  end, opt("close panel"))
  vim.keymap.set("n", "?", open_help, opt("toggle help"))
  vim.keymap.set("n", "<Tab>", function()
    if win_ok(ui.term_win) then
      vim.api.nvim_set_current_win(ui.term_win)
      vim.cmd("startinsert")
    end
  end, opt("focus terminal"))
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Open the panel.  No-op when already open.
function M.open()
  if panel_complete() then
    return
  end

  if not ensure_panel() then
    return
  end

  -- Auto-create the first terminal when the registry is empty.
  if #terminals == 0 then
    local id = next_id
    next_id = next_id + 1
    local entry = {
      id = id,
      name = "terminal " .. id,
      buf = nil,
      profile = default_profile(),
    }
    table.insert(terminals, entry)
  end

  local t = find_term(active_id) or terminals[1]
  if t then
    show_terminal(t)
  end
end

--- Close the panel windows.
--- Terminal buffers (and their shell jobs) survive so they can be reconnected.
function M.close()
  if win_ok(help_win_h) then
    pcall(vim.api.nvim_win_close, help_win_h, true)
    help_win_h = nil
  end
  for _, w in ipairs({ ui.sidebar_win, ui.term_win }) do
    if win_ok(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  reset_panel_handles()
end

--- Toggle the panel.
function M.toggle()
  if panel_open() then
    M.close()
  else
    M.open()
  end
end

--- Create a new terminal, opening the panel first if needed.
---
---@param name      string|nil  Terminal name; prompts if nil.
---@param prof_name string|nil  Profile name; skips picker if provided.
function M.new_term(name, prof_name)
  local profiles = M.config.profiles
  if #profiles == 0 then
    vim.notify("TermManager: no profiles configured", vim.log.levels.WARN)
    return
  end

  local function create(n, profile)
    local id = next_id
    next_id = next_id + 1
    n = (n and n ~= "") and n or ((profile and profile.name) or ("terminal " .. id))
    local entry = { id = id, name = n, buf = nil, profile = profile or default_profile() }
    table.insert(terminals, entry)

    if not ensure_panel() then
      table.remove(terminals) -- roll back
      return
    end
    show_terminal(entry)
  end

  local function prompt_name(profile)
    if name then
      vim.schedule(function()
        create(name, profile)
      end)
    else
      local default = (profile and profile.name) or ("terminal " .. next_id)
      vim.ui.input({ prompt = "Terminal name: ", default = default }, function(n)
        if n == nil then
          return
        end -- user cancelled
        vim.schedule(function()
          create(n, profile)
        end)
      end)
    end
  end

  if prof_name then
    local prof
    for _, p in ipairs(profiles) do
      if p.name == prof_name then
        prof = p
        break
      end
    end
    if not prof then
      vim.notify("TermManager: unknown profile '" .. prof_name .. "'", vim.log.levels.WARN)
    end
    prompt_name(prof or default_profile())
    return
  end

  if #profiles <= 1 then
    -- Single profile: skip the picker entirely.
    prompt_name(default_profile())
    return
  end

  -- Multiple profiles: present a selection list.
  local display = vim.tbl_map(function(p)
    return string.format("%s  %s", p.icon or "$", p.name)
  end, profiles)

  vim.ui.select(display, { prompt = "Profile:" }, function(_, idx)
    if not idx then
      return
    end -- cancelled
    vim.schedule(function()
      prompt_name(profiles[idx])
    end)
  end)
end

function M.new_automation_term(name)
  M.new_term(name, automation_profile().name)
end

function M.pick_profile(callback, prompt)
  local profiles = M.config.profiles
  if #profiles == 0 then
    vim.notify("TermManager: no profiles configured", vim.log.levels.WARN)
    return
  end

  if #profiles == 1 then
    callback(profiles[1])
    return
  end

  local display = vim.tbl_map(function(p)
    return string.format("%s  %s", p.icon or "$", p.name)
  end, profiles)

  vim.ui.select(display, { prompt = prompt or "Profile:" }, function(_, idx)
    if idx then
      callback(profiles[idx])
    end
  end)
end

function M.show_profiles()
  local lines = {}
  local default_name = default_profile() and default_profile().name or nil

  for _, profile in ipairs(M.config.profiles) do
    local shell = shell_cmd_display(profile.shell or get_shell())
    local marker = profile.name == default_name and " [default]" or ""
    lines[#lines + 1] = string.format("%s %s%s", profile.icon or "$", profile.name, marker)
    lines[#lines + 1] = string.format("    shell: %s", shell ~= "" and shell or "(vim.o.shell)")
    if profile.args and #profile.args > 0 then
      lines[#lines + 1] = "    args: " .. table.concat(profile.args, " ")
    end
    if profile.cwd then
      lines[#lines + 1] = "    cwd: " .. profile.cwd
    end
    lines[#lines + 1] = ""
  end

  if #lines == 0 then
    lines = { "No terminal profiles configured." }
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Terminal Profiles" })
end

--- Delete the terminal with the given id.
---@param id integer
function M.delete_term(id)
  local t, idx = find_term(id)
  if not t then
    return
  end

  if buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  table.remove(terminals, idx)

  if #terminals == 0 then
    active_id = nil
    -- Leave the panel open so the user can see the placeholder and press n.
    render_sidebar()
    update_winbar()
    return
  end

  show_terminal(terminals[math.min(idx, #terminals)])
end

--- Focus (or open) the sidebar window.
function M.focus_sidebar()
  if not panel_open() then
    M.open()
    vim.schedule(function()
      if win_ok(ui.sidebar_win) then
        vim.api.nvim_set_current_win(ui.sidebar_win)
      end
    end)
    return
  end
  if win_ok(ui.sidebar_win) then
    vim.api.nvim_set_current_win(ui.sidebar_win)
  end
end

--- Send a list of text lines to the active terminal via chansend.
---@param lines string[]
function M._send_lines(lines)
  local t = find_term(active_id)
  if not (t and term_alive(t.buf)) then
    vim.notify("TermManager: no active running terminal", vim.log.levels.WARN)
    return
  end
  local ok, chan = pcall(vim.api.nvim_get_option_value, "channel", { buf = t.buf })
  if ok and chan and chan > 0 then
    vim.fn.chansend(chan, table.concat(lines, "\n") .. "\n")
  end
end

--- Send the current visual selection to the active terminal.
--- Trailing blank lines are stripped before sending.
function M.send_selection()
  -- In a visual-mode Lua callback, selection endpoints are available via getpos.
  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local s_line = math.min(anchor[2], cursor[2])
  local e_line = math.max(anchor[2], cursor[2])

  -- Exit visual mode to commit '< and '> marks.
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)

  local buf_lines = vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)

  -- Strip trailing blank lines.
  while #buf_lines > 0 and buf_lines[#buf_lines]:match("^%s*$") do
    buf_lines[#buf_lines] = nil
  end

  if #buf_lines > 0 then
    M._send_lines(buf_lines)
  end
end

--------------------------------------------------------------------------------
-- Autocommands
--------------------------------------------------------------------------------
local aug = vim.api.nvim_create_augroup("TermManager", { clear = true })

-- Apply navigation keymaps to every interactive terminal buffer we open,
-- skipping foreign plugin terminals.
vim.api.nvim_create_autocmd("TermOpen", {
  group = aug,
  callback = function(ev)
    local bname = vim.api.nvim_buf_get_name(ev.buf)
    for _, pat in ipairs(M.config.skip_patterns) do
      if bname:find(pat, 1, true) then
        return
      end
    end
    local ko = function(desc)
      return { buffer = ev.buf, silent = true, desc = desc }
    end

    -- <Esc><Esc> to leave terminal mode (avoids the raw <C-\><C-n> chord).
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], ko("exit terminal mode"))
    -- Window navigation without leaving insert mode.
    vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], ko("go to left window"))
    vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], ko("go to lower window"))
    vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], ko("go to upper window"))
    vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], ko("go to right window"))
    -- From normal mode inside a terminal: jump to the sidebar.
    vim.keymap.set("n", "<leader>zT", M.focus_sidebar, ko("focus sidebar"))
  end,
})

-- Keep ui.* handles consistent when windows are closed externally
-- (e.g. :q, :close, ZZ, another plugin closing the window).
vim.api.nvim_create_autocmd("WinClosed", {
  group = aug,
  callback = function(ev)
    local closed = tonumber(ev.match)
    vim.schedule(function()
      if closed == ui.sidebar_win and not win_ok(ui.sidebar_win) then
        ui.sidebar_win = nil
      end
      if closed == ui.term_win and not win_ok(ui.term_win) then
        ui.term_win = nil
      end
      if not panel_open() then
        reset_panel_handles()
      end
    end)
  end,
})

-- Track buffers deleted externally (:bd, another plugin, etc.)
vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
  group = aug,
  callback = function(ev)
    -- Sidebar buffer deleted externally → close the sidebar window too.
    if ev.buf == ui.sidebar_buf then
      ui.sidebar_buf = nil
      if win_ok(ui.sidebar_win) then
        pcall(vim.api.nvim_win_close, ui.sidebar_win, true)
        ui.sidebar_win = nil
      end
      return
    end
    -- Terminal buffer deleted externally → clear the slot so the next
    -- show_terminal() creates a fresh buffer and shell.
    for _, t in ipairs(terminals) do
      if t.buf == ev.buf then
        t.buf = nil
        vim.schedule(function()
          render_sidebar()
          update_winbar()
        end)
        break
      end
    end
  end,
})

-- Refresh alive/dead indicators whenever a window receives focus.
vim.api.nvim_create_autocmd("WinEnter", {
  group = aug,
  callback = function()
    if panel_open() then
      vim.schedule(render_sidebar)
    end
  end,
})

--------------------------------------------------------------------------------
-- Global keymaps
--------------------------------------------------------------------------------
vim.keymap.set("n", "<leader>zt", M.toggle, { desc = "terminal: toggle panel" })
vim.keymap.set("n", "<leader>zn", M.new_term, { desc = "terminal: new terminal" })
vim.keymap.set("n", "<leader>zT", M.focus_sidebar, { desc = "terminal: focus sidebar" })
vim.keymap.set("n", "<leader>zp", function()
  M.pick_profile(function(profile)
    M.new_term(nil, profile.name)
  end, "New terminal profile:")
end, { desc = "terminal: new from profile" })

-- Visual mode: pipe selection into the active terminal.
vim.keymap.set("x", "<leader>zs", M.send_selection, { desc = "terminal: send selection" })

-- <leader>z1 … <leader>z9: jump directly to the Nth managed terminal.
for i = 1, 9 do
  vim.keymap.set("n", "<leader>z" .. i, function()
    if not terminals[i] then
      vim.notify(string.format("TermManager: no terminal #%d", i), vim.log.levels.INFO)
      return
    end
    if not panel_open() then
      M.open()
    end
    show_terminal(terminals[i])
  end, { desc = string.format("terminal: switch to #%d", i) })
end

vim.api.nvim_create_user_command("TerminalNew", function(opts)
  local name = opts.args ~= "" and opts.args or nil
  M.new_term(name)
end, { nargs = "?", desc = "Open a managed terminal" })

vim.api.nvim_create_user_command("TerminalProfiles", function()
  M.show_profiles()
end, { desc = "Show configured terminal profiles" })

vim.api.nvim_create_user_command("TerminalAutomation", function(opts)
  local name = opts.args ~= "" and opts.args or nil
  M.new_automation_term(name)
end, { nargs = "?", desc = "Open a managed terminal using the automation profile" })

validate_profiles()

return M
