--------------------------------------------------------------------------------
-- terminal_manager/profile_wizard.lua
-- Step-by-step floating-window wizard for creating or editing a profile.
--
-- Each "field" is a row in a scratch buffer.  The user navigates with j/k,
-- hits <CR> to edit the focused field via vim.ui.input / vim.ui.select, and
-- presses <leader><CR> or s to Save.  Pressing q or <Esc> cancels.
--------------------------------------------------------------------------------

local utils = require("custom.terminal_manager.utils")

local M = {}

-- ── Known values for picker fields ────────────────────────────────────────────

local COLORS = { "blue", "green", "red", "yellow", "cyan", "magenta", "orange", "white" }
local ICONS = { "$", "%", ">", "~", "#", "!", "*", "@", "+" }

local function detect_shells()
  local candidates = {
    "bash",
    "zsh",
    "fish",
    "sh",
    "dash",
    "ksh",
    "tcsh",
    "nu",
    "elvish",
    "ion",
    "oil",
    "python3",
    "python",
    "node",
    "ruby",
    "perl",
    "pwsh",
    "powershell",
  }
  local found = {}
  for _, s in ipairs(candidates) do
    if vim.fn.executable(s) == 1 then
      found[#found + 1] = s
    end
  end
  found[#found + 1] = "(enter path…)"
  return found
end

-- ── Wizard state ──────────────────────────────────────────────────────────────

-- Build an ordered list of field descriptors from a profile table.
local function build_fields(profile)
  return {
    {
      key = "name",
      label = "Name",
      help = "Display name for this profile (required)",
      value = profile.name or "",
      edit = "input",
    },
    {
      key = "shell",
      label = "Shell",
      help = "Executable path, or blank to use vim.o.shell",
      value = profile.shell or "",
      edit = "shell_picker",
    },
    {
      key = "args",
      label = "Args",
      help = "Extra shell arguments, space-separated (e.g.  -l  --norc)",
      value = table.concat(profile.args or {}, " "),
      edit = "input",
    },
    {
      key = "cwd",
      label = "Working Dir",
      help = "Initial directory; blank = current directory",
      value = profile.cwd or "",
      edit = "input",
    },
    {
      key = "startup_command",
      label = "Startup Cmd",
      help = "Command sent to the shell immediately after launch (optional)",
      value = profile.startup_command or "",
      edit = "input",
    },
    {
      key = "login_shell",
      label = "Login Shell",
      help = "Auto-prepend -l to args (works with bash/zsh/fish)",
      value = profile.login_shell and "yes" or "no",
      edit = "bool",
    },
    {
      key = "close_on_exit",
      label = "Close on Exit",
      help = "Remove the terminal slot when the shell exits",
      value = profile.close_on_exit and "yes" or "no",
      edit = "bool",
    },
    {
      key = "icon",
      label = "Icon",
      help = "Single character shown in the sidebar and winbar",
      value = profile.icon or "$",
      edit = "icon_picker",
    },
    {
      key = "color",
      label = "Color",
      help = "Accent colour for the status dot",
      value = profile.color or "blue",
      edit = "color_picker",
    },
    {
      key = "keymap",
      label = "Keymap",
      help = "Global keybinding to open/focus this profile (e.g. <leader>zg)",
      value = profile.keymap or "",
      edit = "input",
    },
    {
      key = "description",
      label = "Description",
      help = "Optional one-line description",
      value = profile.description or "",
      edit = "input",
    },
  }
end

-- Serialise field values back to a profile table.
local function fields_to_profile(fields)
  local p = {}
  for _, f in ipairs(fields) do
    local v = f.value
    if f.key == "shell" then
      p.shell = (v == "" or v == "(enter path…)") and nil or v
    elseif f.key == "args" then
      -- Split by whitespace
      local parts = {}
      for tok in v:gmatch("%S+") do
        parts[#parts + 1] = tok
      end
      p.args = parts
    elseif f.key == "login_shell" then
      p.login_shell = v == "yes"
    elseif f.key == "close_on_exit" then
      p.close_on_exit = v == "yes"
    elseif f.key == "cwd" then
      p.cwd = (v == "") and nil or v
    elseif f.key == "startup_command" then
      p.startup_command = (v == "") and nil or v
    elseif f.key == "keymap" then
      p.keymap = (v == "") and nil or v
    else
      p[f.key] = v
    end
  end
  -- Defaults for fields not listed above
  p.env = p.env or {}
  p.override_name = p.override_name or false
  return p
end

-- ── Buffer rendering ──────────────────────────────────────────────────────────

local TITLE_W = 14 -- width of the label column
local VALUE_W = 28 -- width of the value column
local TOTAL_W = TITLE_W + VALUE_W + 4

local function render(buf, fields, cursor_field, mode)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  local ns = vim.api.nvim_create_namespace("TermManagerWizard")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = {}
  local field_rows = {} -- { [field_index] = 1-based row }

  -- Title
  lines[#lines + 1] = string.format("  %s", mode == "edit" and "Edit Profile" or "New Profile")
  lines[#lines + 1] = "  " .. ("─"):rep(TOTAL_W - 4)
  lines[#lines + 1] = ""

  -- Field rows
  for i, f in ipairs(fields) do
    field_rows[i] = #lines + 1
    local label = f.label
    local pad = string.rep(" ", math.max(0, TITLE_W - #label))
    -- Truncate value if too long
    local val = tostring(f.value)
    if #val > VALUE_W then
      val = val:sub(1, VALUE_W - 1) .. "…"
    end
    lines[#lines + 1] = string.format("  %s%s  %s", label, pad, val)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. ("─"):rep(TOTAL_W - 4)

  -- Help text for the focused field
  local focused = fields[cursor_field]
  if focused then
    lines[#lines + 1] = "  " .. (focused.help or "")
  else
    lines[#lines + 1] = ""
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  <CR> edit  ·  s / <C-s> save  ·  q cancel"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Highlights
  -- Title
  require("custom.ui.render").add_highlight(buf, ns, "Title", 0, 0, -1)
  require("custom.ui.render").add_highlight(buf, ns, "FloatBorder", 1, 0, -1)

  for i, f in ipairs(fields) do
    local row = field_rows[i] - 1 -- 0-based
    if i == cursor_field then
      require("custom.ui.render").add_highlight(buf, ns, "PmenuSel", row, 0, -1)
    else
      require("custom.ui.render").add_highlight(buf, ns, "Normal", row, 0, -1)
    end
    -- Highlight the label in Comment, value in Normal
    local label_end = 2 + #f.label
    require("custom.ui.render").add_highlight(buf, ns, "Comment", row, 2, label_end)
    local val_start = 2 + TITLE_W + 2
    require("custom.ui.render").add_highlight(buf, ns, "String", row, val_start, -1)
  end

  -- Footer line highlight
  local footer_row = #lines - 1
  require("custom.ui.render").add_highlight(buf, ns, "Comment", footer_row, 0, -1)

  return field_rows
end

-- ── Edit a single field ───────────────────────────────────────────────────────

local function edit_field(f, win, buf, fields, cursor_field, mode, on_change)
  local et = f.edit

  local function done(new_val)
    if new_val ~= nil then
      f.value = new_val
      on_change()
    end
    -- Restore focus to wizard window
    if utils.win_ok(win) then
      vim.api.nvim_set_current_win(win)
    end
  end

  if et == "input" then
    vim.ui.input({ prompt = f.label .. ": ", default = f.value, zindex = 160 }, function(v)
      done(v)
    end)
  elseif et == "shell_picker" then
    local shells = detect_shells()
    local display = shells
    vim.ui.select(display, { prompt = "Select shell:" }, function(choice, _)
      if not choice then
        done(nil)
        return
      end
      if choice == "(enter path…)" then
        vim.ui.input({ prompt = "Shell path: ", default = f.value, zindex = 160 }, function(v)
          done(v)
        end)
      else
        done(choice)
      end
    end)
  elseif et == "bool" then
    vim.ui.select({ "yes", "no" }, { prompt = f.label .. ":" }, function(choice)
      done(choice)
    end)
  elseif et == "icon_picker" then
    local options = vim.list_extend(vim.deepcopy(ICONS), { "(enter custom…)" })
    vim.ui.select(options, { prompt = "Icon:" }, function(choice)
      if not choice then
        done(nil)
        return
      end
      if choice == "(enter custom…)" then
        vim.ui.input({ prompt = "Custom icon (1 char): ", default = f.value, zindex = 160 }, function(v)
          done(v and v:sub(1, 1) or nil)
        end)
      else
        done(choice)
      end
    end)
  elseif et == "color_picker" then
    vim.ui.select(COLORS, { prompt = "Accent color:" }, function(choice)
      done(choice)
    end)
  end
end

-- ── Public: open wizard ────────────────────────────────────────────────────────

--- Open the profile wizard.
---@param existing_profile table|nil  Pass a profile to edit it; nil = create new.
---@param on_save fun(profile: table)  Called with the final profile on save.
function M.open(existing_profile, on_save)
  local mode = existing_profile and "edit" or "new"
  local fields = build_fields(existing_profile or {})

  local height = #fields + 9
  local width = TOTAL_W + 4
  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local buf = require("custom.ui.buffer").create_raw(false, true)
  utils.buf_opt(buf, "filetype", "TermManagerWizard")
  utils.buf_opt(buf, "modifiable", false)

  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = mode == "edit" and " Edit Profile " or " New Profile ",
    title_pos = "center",
    noautocmd = false,
    zindex = 150,
  })

  utils.win_opt(win, "cursorline", false)
  utils.win_opt(win, "winhighlight", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")

  local cursor_field = 1
  local field_rows = {}

  local function refresh()
    field_rows = render(buf, fields, cursor_field, mode)
    -- Set the cursor on the correct buffer row.
    if utils.win_ok(win) and field_rows[cursor_field] then
      pcall(vim.api.nvim_win_set_cursor, win, { field_rows[cursor_field], 2 })
    end
  end

  refresh()

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  local function save()
    local p = fields_to_profile(fields)
    if not p.name or p.name == "" then
      vim.notify("TermManager: profile name is required", vim.log.levels.WARN)
      return
    end
    close()
    on_save(p)
  end

  local ko = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set("n", "j", function()
    cursor_field = math.min(#fields, cursor_field + 1)
    refresh()
  end, ko)

  vim.keymap.set("n", "k", function()
    cursor_field = math.max(1, cursor_field - 1)
    refresh()
  end, ko)

  vim.keymap.set("n", "<CR>", function()
    local f = fields[cursor_field]
    if f then
      edit_field(f, win, buf, fields, cursor_field, mode, refresh)
    end
  end, ko)

  vim.keymap.set("n", "s", save, ko)
  vim.keymap.set("n", "<C-s>", save, ko)
  vim.keymap.set("n", "q", close, ko)
  vim.keymap.set("n", "<Esc>", close, ko)
end

return M
