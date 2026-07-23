-- custom/explorer/search.lua
--
-- Search input lives in the fixed overlay managed by search_ui. Results remain
-- in S.win, so moving through them scrolls only the tree.
--
-- Buffer lines:
--   1    FILTER
--   2    󰍉  <query>       n/m     ← cursor here when active (insert mode)
--   3                               ← quiet spacing before the tree
--   4+ S.items[1], S.items[2], …
--
-- Insert-mode keymaps (search active only):
--   <CR>              confirm (keep filter); cursor lands on selected result
--   <Esc> / <C-c>     clear filter and exit insert
--   <C-u> / <C-l>     wipe filter text, stay in insert
--   <BS>              blocked at/before icon boundary
--   <Home> / <C-a>    jump to start of filter text
--   <C-v> / <S-Ins>   paste from clipboard
--   <C-j>/<C-n>/<Down>   move result cursor down
--   <C-k>/<C-p>/<Up>     move result cursor up

local S = require("custom.explorer.state")
local render = require("custom.explorer.render")
local search_ui = require("custom.explorer.search_ui")
local tree = require("custom.explorer.tree")
local str_utils = require("utils.strings")
local api = vim.api

local ICON_PREFIX = render.ICON_PREFIX

local M = {}

local function input_buf()
  return S.search_buf
end

local function input_win()
  return S.search_win
end

-- ── Result cursor helpers ─────────────────────────────────────────────────

local function clamp_cursor()
  local n = #S.items
  if n == 0 then
    S._search_cursor = 0
  else
    S._search_cursor = math.max(1, math.min(S._search_cursor or 1, n))
  end
end

function M._compute_result_topline(topline, height, first_item_line, item_count, target_line)
  local visible_capacity = math.max(height or 0, 1)
  local current_topline = math.max(topline or first_item_line, first_item_line)
  local edge_padding = math.min(2, math.max(visible_capacity - 1, 0))
  local bottomline = current_topline + visible_capacity - 1

  if item_count <= visible_capacity then
    return first_item_line
  end

  local min_visible = current_topline + edge_padding
  local max_visible = bottomline - edge_padding

  if target_line < min_visible then
    return math.max(first_item_line, target_line - edge_padding)
  end
  if target_line > max_visible then
    return math.max(first_item_line, target_line - visible_capacity + edge_padding + 1)
  end
  return current_topline
end

local function scroll_to_result_cursor()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  local idx = S._search_cursor
  if not idx or idx < 1 or idx > #S.items then
    return
  end

  local first_item_line = search_ui.line_for_item(1)
  local target_line = search_ui.line_for_item(idx)
  local height = api.nvim_win_get_height(S.win)

  api.nvim_win_call(S.win, function()
    local view = vim.fn.winsaveview()
    local topline = math.max(view.topline, first_item_line)
    local next_topline = M._compute_result_topline(topline, height, first_item_line, #S.items, target_line)
    if next_topline ~= topline then
      view.topline = next_topline
      vim.fn.winrestview(view)
    end
  end)
end

-- ── Match / cursor painting ───────────────────────────────────────────────

local function paint_match_layer()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.match_ns, search_ui.HEADER_LINES, -1)

  local idx = S._search_cursor
  if idx and idx >= 1 and idx <= #S.items then
    pcall(require("custom.ui.render").set_extmark, buf, S.match_ns, search_ui.row_for_item(idx), 0, {
      end_col = -1,
      hl_group = "ExplorerSearchCursor",
      hl_eol = true,
      priority = 35,
    })
  end

  if S.filter and S.filter ~= "" then
    for i, item in ipairs(S.items) do
      local positions = item._match_positions
      if positions and item._col_name then
        for _, byte_pos in ipairs(positions) do
          local buf_col = item._col_name + byte_pos - 1
          pcall(require("custom.ui.render").set_extmark, buf, S.match_ns, search_ui.row_for_item(i), buf_col, {
            end_col = buf_col + 1,
            hl_group = "ExplorerSearchMatch",
            priority = 40,
          })
        end
      end
    end
  end
end

-- ── Score items ─────────────────────────────────────────────────────────

local function score_items(items, filter)
  if not filter or filter == "" then
    return items
  end
  for _, item in ipairs(items) do
    local score, positions = str_utils.fuzzy_match(item.name, filter)
    item._match_score = score or 0
    item._match_positions = positions or {}
  end
  return items
end

-- ── Debounced rebuild ─────────────────────────────────────────────────────

local _rebuild_timer = nil

local function rebuild_items()
  S.build_tok = S.build_tok + 1
  local tok = S.build_tok

  if _rebuild_timer then
    _rebuild_timer:stop()
    _rebuild_timer = nil
  end

  _rebuild_timer = vim.defer_fn(function()
    _rebuild_timer = nil
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
      return
    end
    tok = S.build_tok
    tree.build(
      tok,
      S.filter,
      vim.schedule_wrap(function(items)
        if S.build_tok ~= tok then
          return
        end

        local prev_path = S._search_cursor and S.items[S._search_cursor] and S.items[S._search_cursor].path
        S.items = score_items(items, S.filter)
        S._search_cursor = #S.items > 0 and 1 or 0
        if prev_path then
          for i, it in ipairs(S.items) do
            if it.path == prev_path then
              S._search_cursor = i
              break
            end
          end
        end

        render._paint_items_only()
        render.paint_header()
        paint_match_layer()
      end)
    )
  end, 20)
end

-- ── Clipboard paste ───────────────────────────────────────────────────────

local function paste_from_clipboard()
  local text = vim.fn.getreg("+")
  if not text or text == "" then
    text = vim.fn.getreg("*")
  end
  if not text or text == "" then
    return
  end
  api.nvim_paste(text, true, -1)
end

-- ── Helpers ───────────────────────────────────────────────────────────────

local function set_buf_modifiable(buf, v)
  api.nvim_set_option_value("modifiable", v, { buf = buf })
end

local function strip_prefix(raw)
  return search_ui.strip_prefix(raw)
end

local function kill_completion(buf)
  vim.b[buf].completion = false
  vim.b[buf].blink_cmp_enabled = false
  vim.b[buf].cmp_enabled = false
  vim.b[buf].coq_settings = { completion = { enabled = false } }
  vim.b[buf].completion_enabled = false
  pcall(function()
    vim.bo[buf].omnifunc = ""
  end)
  pcall(function()
    vim.bo[buf].completefunc = ""
  end)
end

local function restore_completion(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.b[buf].completion = nil
  vim.b[buf].blink_cmp_enabled = nil
  vim.b[buf].cmp_enabled = nil
  vim.b[buf].coq_settings = nil
  vim.b[buf].completion_enabled = nil
  local ok, blink = pcall(require, "blink.cmp")
  if ok and type(blink.enable) == "function" then
    pcall(blink.enable, buf)
  end
end

-- ── activate ──────────────────────────────────────────────────────────────

function M.activate()
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  S.search_active = true
  search_ui.ensure_window()
  if not (input_buf() and api.nvim_buf_is_valid(input_buf())) then
    return
  end

  -- If already active just reposition cursor
  if api.nvim_get_current_win() == input_win() then
    local col = #ICON_PREFIX + #(S.filter or "")
    pcall(api.nvim_win_set_cursor, input_win(), { search_ui.INPUT_LNUM, col })
    vim.cmd("startinsert!")
    return
  end

  S._search_cursor = #S.items > 0 and 1 or 0

  kill_completion(input_buf())

  -- Make the buffer writable and write the current header state
  set_buf_modifiable(input_buf(), true)
  local filter_text = S.filter or ""
  local header = search_ui.header_lines(filter_text)
  api.nvim_buf_set_lines(input_buf(), 0, search_ui.HEADER_LINES, false, header)

  -- Paint immediately so the active state shows before the user types
  render.paint_header()

  if #S.items > 0 then
    render._paint_items_only()
  else
    rebuild_items()
  end
  paint_match_layer()

  -- Move cursor to input row, column at end of filter text, enter insert
  local col = #ICON_PREFIX + #filter_text
  search_ui.ensure_window()
  pcall(api.nvim_set_current_win, input_win())
  pcall(api.nvim_win_set_cursor, input_win(), { search_ui.INPUT_LNUM, col })
  vim.cmd("startinsert!")
end

-- ── deactivate (internal) ─────────────────────────────────────────────────

local function deactivate(clear_filter, target_row)
  if not S.search_active then
    return
  end
  S.search_active = false
  S._search_cursor = nil

  if input_buf() and api.nvim_buf_is_valid(input_buf()) then
    api.nvim_buf_clear_namespace(input_buf(), S.match_ns, 0, -1)
  end

  -- Read the query text the user typed from the overlay input row.
  local raw = (input_buf() and api.nvim_buf_is_valid(input_buf()))
      and (api.nvim_buf_get_lines(input_buf(), search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false)[1] or "")
    or ""
  local text = strip_prefix(raw)

  S.filter = (not clear_filter and text ~= "") and text or nil

  if clear_filter then
    for _, item in ipairs(S.items) do
      item._match_score = nil
      item._match_positions = nil
    end
  end

  restore_completion(input_buf())
  set_buf_modifiable(input_buf(), false)

  require("custom.explorer.win").apply_window_options(S.win)

  render.render()

  vim.schedule(function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      return
    end
    pcall(api.nvim_set_current_win, S.win)
    if #S.items == 0 then
      return
    end
    local desired = target_row or api.nvim_win_get_cursor(S.win)[1]
    local row = math.max(search_ui.line_for_item(1), math.min(desired, search_ui.line_for_item(#S.items)))
    pcall(api.nvim_win_set_cursor, S.win, { row, 0 })
  end)
end

-- ── on_items_updated (called by render when search is active) ─────────────

function M.on_items_updated()
  if not S.search_active then
    return
  end
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    return
  end

  S.items = score_items(S.items, S.filter)
  clamp_cursor()
  render._paint_items_only()
  render.paint_header()
  paint_match_layer()

  -- Restore cursor to input row
  local col = #ICON_PREFIX + #(S.filter or "")
  if api.nvim_get_current_win() == input_win() then
    pcall(api.nvim_win_set_cursor, input_win(), { search_ui.INPUT_LNUM, col })
    vim.cmd("startinsert!")
  end
end

-- ── setup: attach autocmds and keymaps to S.buf ───────────────────────────

function M.setup(buf)
  search_ui.ensure_window()
  buf = input_buf()
  local bopts = { buffer = buf, silent = true, noremap = true }
  local group = api.nvim_create_augroup("ExplorerSearch_" .. buf, { clear = true })
  local quit = require("custom.explorer.config").get().keymaps.quit
  if quit and quit ~= "" then
    vim.keymap.set("n", quit, function()
      if S.close_fn then
        S.close_fn()
      end
    end, { buffer = buf, silent = true, noremap = true, desc = "close explorer" })
  end

  -- Live filter: TextChangedI fires while user types in insert mode on line 2
  api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = buf,
    callback = function()
      if not S.search_active then
        return
      end
      -- Only process input on the input row
      if not (input_win() and api.nvim_win_is_valid(input_win())) then
        return
      end
      if api.nvim_get_current_win() ~= input_win() then
        return
      end
      if api.nvim_win_get_cursor(input_win())[1] ~= search_ui.INPUT_LNUM then
        return
      end

      local raw = api.nvim_buf_get_lines(buf, search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false)[1] or ""
      local t = strip_prefix(raw)
      S.filter = t ~= "" and t or nil
      rebuild_items()
    end,
  })

  -- InsertLeave: commit or discard
  api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      if not S.search_active then
        return
      end
      -- Only deactivate if the cursor was on the input row when insert ended
      local row = (input_win() and api.nvim_win_is_valid(input_win()))
          and api.nvim_win_get_cursor(input_win())[1]
        or 0
      if row ~= search_ui.INPUT_LNUM then
        return
      end
      local target_row = S._post_search_row
      S._post_search_row = nil
      deactivate(S._search_clear_on_leave, target_row)
      S._search_clear_on_leave = false
    end),
  })

  -- Block completion popups
  for _, k in ipairs({
    "<C-x><C-o>",
    "<C-x><C-n>",
    "<C-x><C-p>",
    "<C-x><C-f>",
    "<C-x><C-l>",
    "<C-x><C-s>",
    "<C-x><C-k>",
    "<Tab>",
    "<S-Tab>",
    "<C-y>",
    "<C-e>",
  }) do
    vim.keymap.set("i", k, "<Nop>", bopts)
  end

  -- <CR>: confirm and land on selected result
  vim.keymap.set("i", "<CR>", function()
    if not S.search_active then
      return
    end
    S._search_clear_on_leave = false
    local idx = S._search_cursor or 0
    S._post_search_row = idx > 0 and search_ui.line_for_item(idx) or nil
    vim.cmd("stopinsert")
  end, bopts)

  -- <Esc> / <C-c>: discard filter
  local function discard_search()
    if not S.search_active then
      return
    end
    S._search_clear_on_leave = true
    vim.cmd("stopinsert")
  end
  vim.keymap.set("i", "<Esc>", discard_search, bopts)
  vim.keymap.set("i", "<C-c>", discard_search, bopts)

  -- <C-u> / <C-l>: wipe filter text
  local function wipe_filter()
    if not S.search_active then
      return
    end
    api.nvim_buf_set_lines(buf, search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false, { search_ui.line_text("") })
    S.filter = nil
    S._search_cursor = 0
    pcall(api.nvim_win_set_cursor, input_win(), { search_ui.INPUT_LNUM, #ICON_PREFIX })
    render.paint_header()
    rebuild_items()
  end
  vim.keymap.set("i", "<C-u>", wipe_filter, bopts)
  vim.keymap.set("i", "<C-l>", wipe_filter, bopts)

  -- <BS>: block deletion into the icon prefix
  vim.keymap.set("i", "<BS>", function()
    if not S.search_active then
      return "<BS>"
    end
    if not (input_win() and api.nvim_win_is_valid(input_win())) then
      return "<BS>"
    end
    local col = api.nvim_win_get_cursor(input_win())[2]
    return col <= #ICON_PREFIX and "" or "<BS>"
  end, { buffer = buf, silent = true, noremap = true, expr = true })

  -- <Home> / <C-a>: jump to filter start
  local function to_filter_start()
    if not S.search_active then
      return
    end
    pcall(api.nvim_win_set_cursor, input_win(), { search_ui.INPUT_LNUM, #ICON_PREFIX })
  end
  vim.keymap.set("i", "<Home>", to_filter_start, bopts)
  vim.keymap.set("i", "<C-a>", to_filter_start, bopts)

  -- Clipboard paste
  vim.keymap.set("i", "<C-v>", paste_from_clipboard, bopts)
  vim.keymap.set("i", "<S-Insert>", paste_from_clipboard, bopts)

  -- <C-j>/<C-n>/<Down>: result cursor down
  local function cursor_down()
    if not S.search_active then
      return
    end
    S._search_cursor = (S._search_cursor or 1) + 1
    clamp_cursor()
    paint_match_layer()
    render.paint_header()
    scroll_to_result_cursor()
  end
  vim.keymap.set("i", "<C-j>", cursor_down, bopts)
  vim.keymap.set("i", "<C-n>", cursor_down, bopts)
  vim.keymap.set("i", "<Down>", cursor_down, bopts)

  -- <C-k>/<C-p>/<Up>: result cursor up
  local function cursor_up()
    if not S.search_active then
      return
    end
    S._search_cursor = (S._search_cursor or 1) - 1
    clamp_cursor()
    paint_match_layer()
    render.paint_header()
    scroll_to_result_cursor()
  end
  vim.keymap.set("i", "<C-k>", cursor_up, bopts)
  vim.keymap.set("i", "<C-p>", cursor_up, bopts)
  vim.keymap.set("i", "<Up>", cursor_up, bopts)
end

-- ── close / clear (called externally) ────────────────────────────────────

function M.close()
  if S.search_active then
    S.search_active = false
    S._search_cursor = nil
    if input_buf() and api.nvim_buf_is_valid(input_buf()) then
      pcall(api.nvim_set_option_value, "modifiable", false, { buf = input_buf() })
      api.nvim_buf_clear_namespace(input_buf(), S.match_ns, 0, -1)
    end
  end
  search_ui.close()
end

function M.clear()
  S.filter = nil
  S.search_active = false
  S._search_cursor = nil
  if input_buf() and api.nvim_buf_is_valid(input_buf()) then
    pcall(api.nvim_set_option_value, "modifiable", false, { buf = input_buf() })
    api.nvim_buf_clear_namespace(input_buf(), S.match_ns, 0, -1)
  end
  render.render()
end

return M
