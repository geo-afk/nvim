--------------------------------------------------------------------------------
-- custom/terminal_manager/search.lua
-- Floating search bar for terminal buffers.
--
-- In terminal (normal) mode, press <C-f> (or the configured key) to open.
-- Type a pattern, press Enter to jump to the first match, n/N to navigate.
-- Supports plain text and Lua magic-pattern search.
-- The search is done by reading the terminal scrollback into a scratch buffer,
-- searching there, then mapping line numbers back to the real terminal.
--------------------------------------------------------------------------------

local utils = require("custom.terminal_manager.utils")

local M = {}

-- ── State ─────────────────────────────────────────────────────────────────────

local active = {
  term_buf = nil, -- the terminal buffer being searched
  term_win = nil, -- the terminal window
  pattern = "", -- last search pattern
  matches = {}, -- { lnum, col_s, col_e }
  cursor = 0, -- index into matches (1-based)
  float_win = nil,
  float_buf = nil,
}

local FLOAT_W = 46
local FLOAT_H = 4

local ns = vim.api.nvim_create_namespace("TermManagerSearch")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function close_float()
  if utils.win_ok(active.float_win) then
    pcall(vim.api.nvim_win_close, active.float_win, true)
  end
  if utils.buf_ok(active.float_buf) then
    pcall(vim.api.nvim_buf_delete, active.float_buf, { force = true })
  end
  active.float_win = nil
  active.float_buf = nil
end

local function clear_highlights()
  if utils.buf_ok(active.term_buf) then
    vim.api.nvim_buf_clear_namespace(active.term_buf, ns, 0, -1)
  end
end

local function highlight_matches()
  clear_highlights()
  if not utils.buf_ok(active.term_buf) then
    return
  end
  for i, m in ipairs(active.matches) do
    local hl = (i == active.cursor) and "IncSearch" or "Search"
    pcall(vim.api.nvim_buf_add_highlight, active.term_buf, ns, hl, m.lnum, m.col_s, m.col_e)
  end
end

local function jump_to_cursor_match()
  if #active.matches == 0 then
    return
  end
  local m = active.matches[active.cursor]
  if not m then
    return
  end
  if utils.win_ok(active.term_win) then
    pcall(vim.api.nvim_win_set_cursor, active.term_win, { m.lnum + 1, m.col_s })
    -- scroll the window so the match is visible
    vim.api.nvim_win_call(active.term_win, function()
      vim.cmd("normal! zz")
    end)
  end
end

local function update_prompt_line()
  if not utils.buf_ok(active.float_buf) then
    return
  end
  local total = #active.matches
  local cur = active.cursor
  local info = total > 0 and string.format(" [%d/%d]", cur, total) or " [no matches]"
  local line2 = "  " .. string.rep("─", FLOAT_W - 4)
  local line3 = string.format("  Pattern: %s%s", active.pattern, info)
  local line4 = "  n next  N prev  <Esc>/<CR> close"
  vim.api.nvim_set_option_value("modifiable", true, { buf = active.float_buf })
  vim.api.nvim_buf_set_lines(active.float_buf, 1, -1, false, { line2, line3, line4 })
  vim.api.nvim_set_option_value("modifiable", false, { buf = active.float_buf })
end

--- Run the search against the terminal buffer content.
local function do_search(pattern)
  active.matches = {}
  active.cursor = 0
  if not pattern or pattern == "" then
    clear_highlights()
    update_prompt_line()
    return
  end

  if not utils.buf_ok(active.term_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(active.term_buf, 0, -1, false)
  local ok_pat, err = pcall(string.find, "test", pattern)
  if not ok_pat then
    -- Bad pattern – try literal
    pattern = vim.pesc(pattern)
  end

  for lnum, text in ipairs(lines) do
    local s = 1
    while s <= #text do
      local ms, me = text:find(pattern, s)
      if not ms then
        break
      end
      active.matches[#active.matches + 1] = {
        lnum = lnum - 1, -- 0-based
        col_s = ms - 1,
        col_e = me,
      }
      s = me + 1
    end
  end

  -- Start at the match nearest to the current cursor line.
  if #active.matches > 0 and utils.win_ok(active.term_win) then
    local cur_line = vim.api.nvim_win_get_cursor(active.term_win)[1] - 1
    active.cursor = 1
    for i, m in ipairs(active.matches) do
      if m.lnum >= cur_line then
        active.cursor = i
        break
      end
    end
  end

  highlight_matches()
  jump_to_cursor_match()
  update_prompt_line()
end

-- ── Public ────────────────────────────────────────────────────────────────────

--- Navigate to the next match.
function M.next()
  if #active.matches == 0 then
    return
  end
  active.cursor = (active.cursor % #active.matches) + 1
  highlight_matches()
  jump_to_cursor_match()
  update_prompt_line()
end

--- Navigate to the previous match.
function M.prev()
  if #active.matches == 0 then
    return
  end
  active.cursor = ((active.cursor - 2) % #active.matches) + 1
  highlight_matches()
  jump_to_cursor_match()
  update_prompt_line()
end

--- Open the search float for the given terminal buffer/window.
---@param term_buf integer
---@param term_win integer
function M.open(term_buf, term_win)
  if not utils.buf_ok(term_buf) then
    return
  end

  -- Close existing float if re-opened.
  if utils.win_ok(active.float_win) then
    close_float()
    clear_highlights()
    active.pattern = ""
    active.matches = {}
    active.cursor = 0
  end

  active.term_buf = term_buf
  active.term_win = term_win

  -- Build the float buffer.
  local fbuf = vim.api.nvim_create_buf(false, true)
  active.float_buf = fbuf
  vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, {
    "  🔍 Search terminal  (type to filter)",
    "  " .. string.rep("─", FLOAT_W - 4),
    "  Pattern: ",
    "  n next  N prev  <Esc>/<CR> close",
  })
  utils.buf_opt(fbuf, "modifiable", false)

  -- Position at bottom-right of the terminal window (if valid).
  local row_off, col_off = 2, 2
  if utils.win_ok(term_win) then
    local tw_pos = vim.api.nvim_win_get_position(term_win)
    local tw_h = vim.api.nvim_win_get_height(term_win)
    row_off = tw_pos[1] + tw_h - FLOAT_H - 1
    col_off = tw_pos[2] + 2
  end

  local fwin = vim.api.nvim_open_win(fbuf, false, {
    relative = "editor",
    row = math.max(0, row_off),
    col = math.max(0, col_off),
    width = FLOAT_W,
    height = FLOAT_H,
    style = "minimal",
    border = "rounded",
    title = " Search ",
    title_pos = "center",
    noautocmd = true,
    focusable = false,
  })
  active.float_win = fwin
  utils.win_opt(fwin, "winblend", 5)

  -- Input loop: collect keystrokes, update on each one.
  -- We use vim.ui.input in a non-blocking way by using a wrapper.
  vim.ui.input({ prompt = "Search: ", default = active.pattern }, function(input)
    if input == nil then
      -- Cancelled
      close_float()
      clear_highlights()
      return
    end
    active.pattern = input
    do_search(input)
    -- Reopen the float with navigation only (no more text input).
    update_prompt_line()

    -- After input closes, focus remains in the terminal – add temp keymaps.
    if utils.win_ok(term_win) then
      vim.api.nvim_set_current_win(term_win)
      local ko = { buffer = term_buf, nowait = true, silent = true }
      vim.keymap.set("n", "n", function()
        M.next()
      end, vim.tbl_extend("force", ko, { desc = "search: next match" }))
      vim.keymap.set("n", "N", function()
        M.prev()
      end, vim.tbl_extend("force", ko, { desc = "search: prev match" }))
      vim.keymap.set("n", "<Esc>", function()
        close_float()
        clear_highlights()
        -- Restore normal <Esc><Esc> behaviour
        pcall(vim.keymap.del, "n", "n", { buffer = term_buf })
        pcall(vim.keymap.del, "n", "N", { buffer = term_buf })
        pcall(vim.keymap.del, "n", "<Esc>", { buffer = term_buf })
      end, vim.tbl_extend("force", ko, { desc = "search: close" }))
    else
      close_float()
    end
  end)
end

--- Close the search float and clear highlights.
function M.close()
  close_float()
  clear_highlights()
  active.pattern = ""
  active.matches = {}
  active.cursor = 0
end

return M
