--------------------------------------------------------------------------------
-- custom.terminal_manager/profile_manager.lua
-- Floating window that lists all profiles, shows their keymaps, and lets the
-- user create / edit / delete / set-as-default profiles.
--
-- Keys inside the manager:
--   j / k          navigate
--   <CR>           open a new terminal with this profile
--   n              create a new profile (opens wizard)
--   e              edit profile under cursor (opens wizard)
--   d              delete profile under cursor
--   D              set profile under cursor as the default
--   q / <Esc>      close
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

local WIDTH = 62
local ns = vim.api.nvim_create_namespace("TermManagerProfileMgr")

-- ── Highlight helpers ─────────────────────────────────────────────────────────

local function setup_hl()
  local function hl(n, o)
    vim.api.nvim_set_hl(0, n, vim.tbl_extend("force", o, { default = true }))
  end
  hl("TMPMgrHeader", { link = "Title" })
  hl("TMPMgrDefault", { link = "DiagnosticOk" })
  hl("TMPMgrKeymap", { link = "SpecialKey" })
  hl("TMPMgrDesc", { link = "Comment" })
  hl("TMPMgrSep", { link = "FloatBorder" })
  hl("TMPMgrActive", { link = "PmenuSel" })
  hl("TMPMgrShell", { link = "Statement" })
  hl("TMPMgrFooter", { link = "Comment" })
end
setup_hl()

-- ── Render ────────────────────────────────────────────────────────────────────

local function render(buf, cursor_idx)
  local cfg = require("custom.terminal_manager").config
  local profiles = cfg.profiles
  local def_name = (require("custom.terminal_manager.profiles").default_profile() or {}).name

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = {}
  local profile_rows = {} -- { [row_1based] = profile_index }

  -- Header
  lines[#lines + 1] = string.format("  Profiles (%d)   [n]ew  [e]dit  [d]el  [D]efault", #profiles)
  lines[#lines + 1] = "  " .. ("─"):rep(WIDTH - 4)
  lines[#lines + 1] = ""

  local ICON_COL = 2
  local NAME_COL = 6
  local SHELL_COL = 28
  local KEY_COL = 46

  -- Column header
  lines[#lines + 1] = string.format("  %-22s %-16s %-14s", "Name", "Shell", "Keymap")
  lines[#lines + 1] = ""

  for i, p in ipairs(profiles) do
    local row = #lines + 1
    profile_rows[row] = i

    local icon = p.icon or "$"
    local name = p.name or "?"
    local is_def = name == def_name
    local shell = p.shell or "(default shell)"
    local km = p.keymap or "—"
    local desc = p.description or ""
    local login = p.login_shell and " [login]" or ""
    local coe = p.close_on_exit and " [exit→close]" or ""
    local startup = p.startup_command and (" ⚡ " .. p.startup_command) or ""

    -- Main row
    lines[#lines + 1] =
      string.format("  %s %-21s %-16s %s", icon, (is_def and "★ " or "  ") .. name, (shell .. login):sub(1, 16), km)

    -- Sub-row: description / flags / startup command
    local sub = ""
    if desc ~= "" then
      sub = sub .. desc
    end
    sub = sub .. coe .. startup
    if sub ~= "" then
      lines[#lines + 1] = string.format("    └─ %s", sub:sub(1, WIDTH - 8))
    end
  end

  if #profiles == 0 then
    lines[#lines + 1] = "  (no profiles — press n to create one)"
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. ("─"):rep(WIDTH - 4)
  lines[#lines + 1] = "  <CR> open terminal  ·  q / <Esc> close"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Header highlights
  vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrHeader", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrSep", 1, 0, -1)
  -- Column header
  vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrDesc", 3, 0, -1)

  -- Per-profile highlights
  for row, idx in pairs(profile_rows) do
    local r0 = row - 1
    local hl_grp = (idx == cursor_idx) and "TMPMgrActive" or "Normal"
    vim.api.nvim_buf_add_highlight(buf, ns, hl_grp, r0, 0, -1)
    -- Star (default marker)
    vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrDefault", r0, 6, 8)
    -- Shell column
    vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrShell", r0, 28, 44)
    -- Keymap column
    vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrKeymap", r0, 46, -1)
  end

  -- Footer
  local last = #lines
  vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrSep", last - 2, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "TMPMgrFooter", last - 1, 0, -1)

  return profile_rows
end

-- ── Public: open manager ──────────────────────────────────────────────────────

function M.open()
  local cfg = require("custom.terminal_manager").config
  local profiles = cfg.profiles
  local total = #profiles

  -- Height: header(5) + per-profile rows (up to 2 each) + footer(3)
  local height = math.min(5 + total * 2 + 3 + 2, vim.o.lines - 4)
  height = math.max(height, 10)

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - WIDTH) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  utils.buf_opt(buf, "filetype", "TermManagerProfileMgr")
  utils.buf_opt(buf, "modifiable", false)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = WIDTH,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Terminal Profiles ",
    title_pos = "center",
    noautocmd = false,
  })

  utils.win_opt(win, "cursorline", false)
  utils.win_opt(win, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  local cursor_idx = 1
  local profile_rows = {}

  local function refresh()
    profile_rows = render(buf, cursor_idx)
    -- Move cursor to the right row
    for r, i in pairs(profile_rows) do
      if i == cursor_idx then
        pcall(vim.api.nvim_win_set_cursor, win, { r, 2 })
        break
      end
    end
  end

  refresh()

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  --- Return the profile at cursor_idx, or nil.
  local function current_profile()
    local profs = require("custom.terminal_manager").config.profiles
    return profs[cursor_idx]
  end

  local ko = { buffer = buf, nowait = true, silent = true }

  -- Navigation
  vim.keymap.set("n", "j", function()
    local profs = require("custom.terminal_manager").config.profiles
    cursor_idx = math.min(#profs, cursor_idx + 1)
    refresh()
  end, ko)

  vim.keymap.set("n", "k", function()
    cursor_idx = math.max(1, cursor_idx - 1)
    refresh()
  end, ko)

  -- Open terminal with this profile
  vim.keymap.set("n", "<CR>", function()
    local p = current_profile()
    if not p then
      return
    end
    close()
    vim.schedule(function()
      require("custom.terminal_manager").new_term(nil, p.name)
    end)
  end, ko)

  -- New profile
  vim.keymap.set("n", "n", function()
    close()
    vim.schedule(function()
      require("custom.terminal_manager.profile_wizard").open(nil, function(p)
        local tm_cfg = require("custom.terminal_manager").config
        -- Prevent duplicate names
        for _, ep in ipairs(tm_cfg.profiles) do
          if ep.name == p.name then
            vim.notify("TermManager: profile '" .. p.name .. "' already exists", vim.log.levels.WARN)
            return
          end
        end
        table.insert(tm_cfg.profiles, p)
        require("custom.terminal_manager.profiles").register_profile_keymaps()
        require("custom.terminal_manager.profile_store").save_all()
        vim.notify("TermManager: profile '" .. p.name .. "' created", vim.log.levels.INFO)
        -- Re-open the manager
        vim.schedule(M.open)
      end)
    end)
  end, ko)

  -- Edit profile
  vim.keymap.set("n", "e", function()
    local p = current_profile()
    if not p then
      return
    end
    close()
    vim.schedule(function()
      require("custom.terminal_manager.profile_wizard").open(vim.deepcopy(p), function(updated)
        local tm_cfg = require("custom.terminal_manager").config
        -- Find and replace the profile by original name
        for i, ep in ipairs(tm_cfg.profiles) do
          if ep.name == p.name then
            tm_cfg.profiles[i] = updated
            break
          end
        end
        require("custom.terminal_manager.profiles").register_profile_keymaps()
        require("custom.terminal_manager.profile_store").save_all()
        vim.notify("TermManager: profile '" .. updated.name .. "' saved", vim.log.levels.INFO)
        vim.schedule(M.open)
      end)
    end)
  end, ko)

  -- Delete profile
  vim.keymap.set("n", "d", function()
    local p = current_profile()
    if not p then
      return
    end
    vim.ui.select({ "Yes, delete it", "Cancel" }, { prompt = "Delete profile '" .. p.name .. "'?" }, function(choice)
      if choice ~= "Yes, delete it" then
        return
      end
      local tm_cfg = require("custom.terminal_manager").config
      for i, ep in ipairs(tm_cfg.profiles) do
        if ep.name == p.name then
          table.remove(tm_cfg.profiles, i)
          break
        end
      end
      cursor_idx = math.max(1, cursor_idx - 1)
      require("custom.terminal_manager.profile_store").save_all()
      vim.notify("TermManager: profile '" .. p.name .. "' deleted", vim.log.levels.INFO)
      if utils.win_ok(win) then
        refresh()
      end
    end)
  end, ko)

  -- Set as default
  vim.keymap.set("n", "D", function()
    local p = current_profile()
    if not p then
      return
    end
    require("custom.terminal_manager").config.default_profile = p.name
    require("custom.terminal_manager.profile_store").save_all()
    vim.notify("TermManager: default profile set to '" .. p.name .. "'", vim.log.levels.INFO)
    refresh()
  end, ko)

  vim.keymap.set("n", "q", close, ko)
  vim.keymap.set("n", "<Esc>", close, ko)
end

return M
