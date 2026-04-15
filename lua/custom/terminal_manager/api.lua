--------------------------------------------------------------------------------
-- terminal_manager/api.lua
-- Public API functions exposed on the main M table.
-- All functions that need the panel, sidebar, or terminal modules use lazy
-- requires (inside function bodies) to avoid circular-require issues.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local profiles = require("custom.terminal_manager.profiles")

local M = {}

-- ── Panel lifecycle ───────────────────────────────────────────────────────────

--- Open the panel.  No-op when already open.
function M.open()
  if utils.panel_complete() then
    return
  end

  if not require("custom.terminal_manager.panel").ensure() then
    return
  end

  -- Auto-create the first terminal when the registry is empty.
  if #state.terminals == 0 then
    local id = state.next_id
    state.next_id = state.next_id + 1
    table.insert(state.terminals, {
      id = id,
      name = "terminal " .. id,
      buf = nil,
      profile = profiles.default_profile(),
    })
  end

  local t = utils.find_term(state.active_id) or state.terminals[1]
  if t then
    require("custom.terminal_manager.terminal").show(t)
  end
end

--- Close the panel windows.
--- Terminal buffers (and their shell jobs) survive so they can be reconnected.
function M.close()
  -- Close the help float first (if open).
  if utils.win_ok(state.help_win_h) then
    pcall(vim.api.nvim_win_close, state.help_win_h, true)
    state.help_win_h = nil
  end
  for _, w in ipairs({ state.ui.sidebar_win, state.ui.term_win }) do
    if utils.win_ok(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  utils.reset_panel_handles()
end

--- Toggle the panel open / closed.
function M.toggle()
  if utils.panel_open() then
    M.close()
  else
    M.open()
  end
end

-- ── Terminal management ───────────────────────────────────────────────────────

--- Create a new terminal, opening the panel first if needed.
---
---@param name      string|nil  Terminal name; prompts user if nil.
---@param prof_name string|nil  Profile name; skips the picker when provided.
function M.new_term(name, prof_name)
  local cfg = require("custom.terminal_manager").config
  local profs = cfg.profiles

  if #profs == 0 then
    vim.notify("TermManager: no profiles configured", vim.log.levels.WARN)
    return
  end

  --- Inner: actually register and display the new terminal entry.
  local function create(n, profile)
    local id = state.next_id
    state.next_id = state.next_id + 1
    n = (n and n ~= "") and n or ((profile and profile.name) or ("terminal " .. id))
    local entry = {
      id = id,
      name = n,
      buf = nil,
      profile = profile or profiles.default_profile(),
    }
    table.insert(state.terminals, entry)

    if not require("custom.terminal_manager.panel").ensure() then
      table.remove(state.terminals) -- roll back on panel failure
      return
    end
    require("custom.terminal_manager.terminal").show(entry)
  end

  --- Inner: prompt for the terminal name, then call create().
  local function prompt_name(profile)
    if name then
      -- Name supplied by caller – skip the prompt.
      vim.schedule(function()
        create(name, profile)
      end)
    else
      local default = (profile and profile.name) or ("terminal " .. state.next_id)
      vim.ui.input({ prompt = "Terminal name: ", default = default }, function(n)
        if n == nil then
          return -- user cancelled
        end
        vim.schedule(function()
          create(n, profile)
        end)
      end)
    end
  end

  -- ── Profile resolution ─────────────────────────────────────────────────
  if prof_name then
    -- Explicit profile name supplied: skip the picker.
    local prof = nil
    for _, p in ipairs(profs) do
      if p.name == prof_name then
        prof = p
        break
      end
    end
    if not prof then
      vim.notify("TermManager: unknown profile '" .. prof_name .. "'", vim.log.levels.WARN)
    end
    prompt_name(prof or profiles.default_profile())
    return
  end

  if #profs <= 1 then
    -- Single profile: skip the picker entirely.
    prompt_name(profiles.default_profile())
    return
  end

  -- Multiple profiles: present a selection list via vim.ui.select.
  local display = vim.tbl_map(function(p)
    return string.format("%s  %s", p.icon or "$", p.name)
  end, profs)

  vim.ui.select(display, { prompt = "Profile:" }, function(_, idx)
    if not idx then
      return -- user cancelled
    end
    vim.schedule(function()
      prompt_name(profs[idx])
    end)
  end)
end

--- Convenience wrapper: new terminal using the automation profile.
function M.new_automation_term(name)
  M.new_term(name, profiles.automation_profile().name)
end

--- Delete the terminal with the given id.
---@param id integer
function M.delete_term(id)
  local t, idx = utils.find_term(id)
  if not t then
    return
  end

  if utils.buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  table.remove(state.terminals, idx)

  if #state.terminals == 0 then
    state.active_id = nil
    -- Leave the panel open so the user can see the placeholder and press n.
    require("custom.terminal_manager.sidebar").render()
    require("custom.terminal_manager.winbar").update()
    return
  end

  -- Show the nearest surviving terminal.
  require("custom.terminal_manager.terminal").show(state.terminals[math.min(idx, #state.terminals)])
end

-- ── Focus helpers ─────────────────────────────────────────────────────────────

--- Focus (or open) the sidebar window.
function M.focus_sidebar()
  if not utils.panel_open() then
    M.open()
    vim.schedule(function()
      if utils.win_ok(state.ui.sidebar_win) then
        vim.api.nvim_set_current_win(state.ui.sidebar_win)
      end
    end)
    return
  end
  if utils.win_ok(state.ui.sidebar_win) then
    vim.api.nvim_set_current_win(state.ui.sidebar_win)
  end
end

-- ── Profile picker ────────────────────────────────────────────────────────────

--- Open a vim.ui.select picker and call `callback(profile)` on selection.
---@param callback fun(profile: table)
---@param prompt   string|nil
function M.pick_profile(callback, prompt)
  local profs = require("custom.terminal_manager").config.profiles
  if #profs == 0 then
    vim.notify("TermManager: no profiles configured", vim.log.levels.WARN)
    return
  end
  if #profs == 1 then
    callback(profs[1])
    return
  end
  local display = vim.tbl_map(function(p)
    return string.format("%s  %s", p.icon or "$", p.name)
  end, profs)
  vim.ui.select(display, { prompt = prompt or "Profile:" }, function(_, idx)
    if idx then
      callback(profs[idx])
    end
  end)
end

--- Show all configured profiles as a vim.notify message.
function M.show_profiles()
  local lines = {}
  local def = profiles.default_profile()
  local def_name = def and def.name or nil

  for _, profile in ipairs(require("custom.terminal_manager").config.profiles) do
    local shell = profiles.shell_cmd_display(profile.shell or utils.get_shell())
    local marker = profile.name == def_name and " [default]" or ""
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

-- ── Send text to terminal ─────────────────────────────────────────────────────

--- Send a list of text lines to the active terminal via chansend.
---@param lines string[]
function M._send_lines(lines)
  local t = utils.find_term(state.active_id)
  if not (t and utils.term_alive(t.buf)) then
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

return M
