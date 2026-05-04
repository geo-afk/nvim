--------------------------------------------------------------------------------
-- custom/terminal_manager/api.lua
-- Public API – open, close, hide, show, toggle, new_term, delete_term, etc.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")
local profiles = require("custom.terminal_manager.profiles")

local M = {}

function M.open(mode)
  local target_mode = mode or "panel"
  if target_mode == "float" then
    if utils.float_open() then
      require("custom.terminal_manager.float").focus()
      return
    end
  elseif target_mode == "panel" and utils.panel_complete() then
    if not state.panel_hidden then
      return
    end
    state.panel_hidden = false
  end

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
    require("custom.terminal_manager.terminal").show(t, target_mode)
  end
end

--- Close all panel windows; terminal jobs stay alive (bufhidden=hide).
function M.close()
  require("custom.terminal_manager.float").close()
  if utils.win_ok(state.help_win_h) then
    pcall(vim.api.nvim_win_close, state.help_win_h, true)
    state.help_win_h = nil
  end
  -- Close split pane first
  if state.split_mode and utils.win_ok(state.ui.term_win2) then
    pcall(vim.api.nvim_win_close, state.ui.term_win2, true)
  end
  for _, w in ipairs({ state.ui.sidebar_win, state.ui.term_win }) do
    if utils.win_ok(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  utils.reset_panel_handles()
  state.panel_hidden = false
end

--- Hide the panel (same as close but semantically "temporary").
function M.hide()
  if not utils.panel_open() then
    return
  end
  M.close()
  state.panel_hidden = true
end

--- Show a previously hidden panel (or open fresh if never opened).
function M.show()
  if utils.panel_open() then
    return
  end
  state.panel_hidden = false
  M.open("panel")
end

function M.toggle()
  if utils.panel_open() then
    M.hide()
  else
    M.show()
  end
end

function M.set_mode(mode)
  state.display_mode = (mode == "float") and "float" or "panel"
  M.close()
  M.open(state.display_mode)
end

function M.toggle_mode()
  if utils.float_open() then
    require("custom.terminal_manager.float").close()
    state.display_mode = "panel"
  else
    state.display_mode = "float"
    M.open("float")
  end
end

function M.new_term(name, prof_name)
  local cfg = require("custom.terminal_manager").config
  local profs = cfg.profiles
  if #profs == 0 then
    vim.notify("TermManager: no profiles configured", vim.log.levels.WARN)
    return
  end

  local function create(n, profile)
    local id = state.next_id
    state.next_id = state.next_id + 1
    n = (n and n ~= "") and n or ((profile and profile.name) or ("terminal " .. id))
    local entry = { id = id, name = n, buf = nil, profile = profile or profiles.default_profile() }
    table.insert(state.terminals, entry)
    if not require("custom.terminal_manager.terminal").show(entry, "panel") then
      table.remove(state.terminals)
      if state.next_id == id + 1 then
        state.next_id = id
      end
    end
  end

  local function prompt_name(profile)
    if name then
      vim.schedule(function()
        create(name, profile)
      end)
    else
      local default = (profile and profile.name) or ("terminal " .. state.next_id)
      vim.ui.input({ prompt = "Terminal name: ", default = default, zindex = 160 }, function(n)
        if n == nil then
          return
        end
        vim.schedule(function()
          create(n, profile)
        end)
      end)
    end
  end

  if prof_name then
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
    prompt_name(profiles.default_profile())
    return
  end

  local display = vim.tbl_map(function(p)
    return string.format("%s  %s", p.icon or "$", p.name)
  end, profs)
  vim.ui.select(display, { prompt = "Profile:" }, function(_, idx)
    if not idx then
      return
    end
    vim.schedule(function()
      prompt_name(profs[idx])
    end)
  end)
end

function M.new_automation_term(name)
  M.new_term(name, profiles.automation_profile().name)
end

function M.delete_term(id)
  local t, idx = utils.find_term(id)
  if not t then
    return
  end
  if utils.buf_ok(t.buf) then
    pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
  end
  -- Clear split references if this terminal was in pane 2
  if state.active_id2 == id then
    state.active_id2 = nil
  end
  table.remove(state.terminals, idx)

  if #state.terminals == 0 then
    state.active_id = nil
    require("custom.terminal_manager.float").close()
    require("custom.terminal_manager.sidebar").render()
    require("custom.terminal_manager.winbar").update_all()
    return
  end
  require("custom.terminal_manager.terminal").show(state.terminals[math.min(idx, #state.terminals)])
end

function M.focus_sidebar()
  if state.display_mode == "float" then
    M.set_mode("panel")
  end
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

function M.show_profiles()
  require("custom.terminal_manager.profile_manager").open()
end

function M.add_env_var()
  require("custom.terminal_manager.env").add_env_var()
end

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

function M.send_selection()
  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local s_line = math.min(anchor[2], cursor[2])
  local e_line = math.max(anchor[2], cursor[2])
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)
  local buf_lines = vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
  while #buf_lines > 0 and buf_lines[#buf_lines]:match("^%s*$") do
    buf_lines[#buf_lines] = nil
  end
  if #buf_lines > 0 then
    M._send_lines(buf_lines)
  end
end

return M
