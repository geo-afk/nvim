-- custom/explorer/search.lua
--
-- Inline search bar embedded as buffer line 1 — always visible,
-- no floating windows required.
--
-- Buffer line 0 always contains:  ICON_PREFIX .. (S.filter or "")
-- An OVERLAY extmark paints the search icon over ICON_PREFIX so the
-- cursor can never land inside the icon glyph.
--
-- ── What's new vs. the old substring filter ──────────────────────────────
--
--  • Fuzzy matching   — sequential character match with consecutive-run bonus;
--                       falls back to exact substring (highest rank).
--  • Scored ranking   — results sorted by match quality; best match on top.
--  • Match highlights — matched characters are lit up inside each tree row
--                       via `S.match_ns` extmarks (ExplorerSearchMatch).
--  • Result cursor    — a virtual selection (ExplorerSearchCursor) tracks
--                       which result is "active" without moving the real cursor
--                       off the search bar.  The badge updates to "N/total".
--
-- ── Insert-mode keymaps (search active only) ─────────────────────────────
--
--   <CR>          confirm (keep filter); cursor lands on selected result
--   <Esc> / <C-c> clear filter and exit insert
--   <C-u> / <C-l> wipe filter text, stay in insert
--   <BS>          blocked when cursor is at/before icon boundary
--   <Home>/<C-a>  jump to start of filter text (col #ICON_PREFIX)
--   <C-v>/<S-Ins> paste from clipboard
--   <C-j>/<C-n>/<Down>  move result cursor down one row
--   <C-k>/<C-p>/<Up>    move result cursor up one row
--   completion keys → <Nop> to prevent popup bleed

local S = require("custom.explorer.state")
local render = require("custom.explorer.render")
local search_ui = require("custom.explorer.search_ui")
local tree = require("custom.explorer.tree")
local api = vim.api

-- Mirror the constant from render so we never hard-code the prefix width.
local ICON_PREFIX = render.ICON_PREFIX

local M = {}

-- ── Fuzzy matching ────────────────────────────────────────────────────────
--
-- fuzzy_match(text, query) → score, positions  or  nil
--
-- Priority:
--   1. Exact substring match  (score = 100 + query length; contiguous positions)
--   2. Sequential fuzzy match (score based on consecutive-run length)
--
-- Positions are 1-based byte offsets into `text`.

local function fuzzy_match(text, query)
  if not query or query == "" then
    return 0, {}
  end

  local lo_text = text:lower()
  local lo_query = query:lower()

  -- ── Fast path: exact substring ────────────────────────────────────────
  local s = lo_text:find(lo_query, 1, true)
  if s then
    local positions = {}
    for i = s, s + #lo_query - 1 do
      positions[#positions + 1] = i
    end
    return 100 + #lo_query, positions
  end

  -- ── Sequential fuzzy match ────────────────────────────────────────────
  local positions = {}
  local score = 0
  local run = 0
  local pos = 1

  for i = 1, #lo_query do
    local ch = lo_query:sub(i, i)
    local found = lo_text:find(ch, pos, true)
    if not found then
      return nil -- hard miss
    end
    positions[#positions + 1] = found
    if found == pos then
      run = run + 1
      score = score + 5 + run * 2 -- consecutive bonus grows with run length
    else
      run = 0
      score = score + 1
    end
    pos = found + 1
  end

  -- Penalise long names so "init.lua" beats "initialize_project.lua"
  score = score - (#lo_text - #lo_query) * 0.05
  return score, positions
end

-- ── Result cursor helpers ─────────────────────────────────────────────────
--
-- S._search_cursor is a 1-based index into S.items.
-- It is the "virtually selected" result while search is active.

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

-- Scroll the window so the result cursor row is visible without actually
-- moving the editor cursor off the search bar.
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

  -- Read, adjust, restore the scroll view without touching the cursor.
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

-- ── Match/cursor painting ─────────────────────────────────────────────────
--
-- Clears S.match_ns from all item rows (rows 1+) then repaints:
--   a) ExplorerSearchCursor  — full-row wash on the selected result
--   b) ExplorerSearchMatch   — per-character highlights on matched bytes

local function paint_match_layer()
  local buf = S.buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  api.nvim_buf_clear_namespace(buf, S.match_ns, search_ui.HEADER_LINES, -1)

  -- a) Result cursor row highlight
  local idx = S._search_cursor
  if idx and idx >= 1 and idx <= #S.items then
    pcall(api.nvim_buf_set_extmark, buf, S.match_ns, search_ui.row_for_item(idx), 0, {
      end_col = -1,
      hl_group = "ExplorerSearchCursor",
      hl_eol = true,
      priority = 35,
    })
  end

  -- b) Per-character match highlights
  if S.filter and S.filter ~= "" then
    for i, item in ipairs(S.items) do
      local positions = item._match_positions
      if positions and item._col_name then
        for _, byte_pos in ipairs(positions) do
          -- byte_pos is 1-based within item.name; convert to buffer column
          local buf_col = item._col_name + byte_pos - 1
          pcall(api.nvim_buf_set_extmark, buf, S.match_ns, search_ui.row_for_item(i), buf_col, {
            end_col = buf_col + 1,
            hl_group = "ExplorerSearchMatch",
            priority = 40,
          })
        end
      end
    end
  end
end

-- ── Score + sort items ────────────────────────────────────────────────────
--
-- After tree.build() returns a filtered list, re-score each item with the
-- fuzzy scorer, attach match positions for the highlight layer, then sort
-- descending by score so the best match appears at the top.
--
-- Items are only sorted when a filter is active.  With no filter the tree
-- structure (dir order, alphabetical) is preserved.

local function score_and_sort(items, filter)
  if not filter or filter == "" then
    return items
  end
  for _, item in ipairs(items) do
    local score, positions = fuzzy_match(item.name, filter)
    item._match_score = score or 0
    item._match_positions = positions or {}
  end
  table.sort(items, function(a, b)
    return (a._match_score or 0) > (b._match_score or 0)
  end)
  return items
end

-- ── Debounced rebuild ─────────────────────────────────────────────────────
--
-- Called on every TextChangedI.  Debounced via _scheduled flag so rapid
-- keystrokes collapse into a single tree build.

local _rebuild_scheduled = false

local function rebuild_items()
  if _rebuild_scheduled then
    return
  end
  _rebuild_scheduled = true
  S.build_tok = S.build_tok + 1
  local tok = S.build_tok

  vim.schedule(function()
    _rebuild_scheduled = false
    if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
      return
    end
    tree.build(
      tok,
      S.filter,
      vim.schedule_wrap(function(items)
        if S.build_tok ~= tok then
          return
        end
        S.items = score_and_sort(items, S.filter)
        -- Reset result cursor to top on every keystroke
        S._search_cursor = #S.items > 0 and 1 or 0
        render._paint_items_only()
        render.paint_header()
        paint_match_layer()
      end)
    )
  end)
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

local function set_buf_modifiable(buf, value)
  api.nvim_set_option_value("modifiable", value, { buf = buf })
end

local function focus_search_window()
  if not (S.search_win and api.nvim_win_is_valid(S.search_win)) then
    return false
  end
  if api.nvim_get_current_win() ~= S.search_win then
    local ok = pcall(api.nvim_set_current_win, S.search_win)
    if not ok then
      return false
    end
  end
  return true
end

local function strip_prefix(raw)
  return search_ui.strip_prefix(raw)
end

-- ── kill / restore completion engines ────────────────────────────────────

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
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    return
  end
  if not (S.win and api.nvim_win_is_valid(S.win)) then
    return
  end
  local search_target_win, search_target_buf = search_ui.ensure_window()
  if not (search_target_win and search_target_buf and api.nvim_buf_is_valid(search_target_buf)) then
    return
  end
  require("custom.explorer.win").apply_window_options(S.win)

  -- If already active, just move the cursor to end of the filter text
  if S.search_active then
    local col = #ICON_PREFIX + #(S.filter or "")
    if not focus_search_window() then
      return
    end
    api.nvim_win_set_cursor(S.search_win, { search_ui.INPUT_LNUM, col })
    vim.cmd("startinsert!")
    return
  end

  S.search_active = true
  S._search_cursor = #S.items > 0 and 1 or 0

  -- Ensure rows 1+ are populated immediately.
  -- Case A: S.items already has entries from a previous render → repaint fast.
  -- Case B: S.items is empty (search opened before first tree build completed,
  --         or explorer was just opened) → trigger a rebuild so items appear
  --         without waiting for the user to type a character.
  if #S.items > 0 then
    render._paint_items_only()
  else
    rebuild_items()
  end
  kill_completion(search_target_buf)

  local filter_text = S.filter or ""
  local line_text = search_ui.line_text(filter_text)

  set_buf_modifiable(search_target_buf, true)
  api.nvim_buf_set_lines(search_target_buf, 0, -1, false, search_ui.header_lines(filter_text))

  -- paint_header reads search_active=true → switches to active bg/icon/badge
  render.paint_header()
  paint_match_layer()

  if not focus_search_window() then
    return
  end
  api.nvim_win_set_cursor(S.search_win, { search_ui.INPUT_LNUM, #line_text })
  vim.cmd("startinsert!")
end

-- ── deactivate (internal) ─────────────────────────────────────────────────

local function deactivate(clear_filter, target_row)
  if not S.search_active then
    return
  end
  S.search_active = false
  S._search_cursor = nil

  -- Clear match/cursor highlights
  if S.buf and api.nvim_buf_is_valid(S.buf) then
    api.nvim_buf_clear_namespace(S.buf, S.match_ns, 0, -1)
  end

  local raw = (S.search_buf and api.nvim_buf_is_valid(S.search_buf))
      and (api.nvim_buf_get_lines(S.search_buf, search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false)[1] or "")
    or ""
  local text = strip_prefix(raw)

  S.filter = (not clear_filter and text ~= "") and text or nil

  -- Discard match metadata when the filter is cleared
  if clear_filter then
    for _, item in ipairs(S.items) do
      item._match_score = nil
      item._match_positions = nil
    end
  end

  restore_completion(S.search_buf)

  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    set_buf_modifiable(S.search_buf, false)
  end
  if S.win and api.nvim_win_is_valid(S.win) then
    require("custom.explorer.win").apply_window_options(S.win)
    pcall(api.nvim_set_current_win, S.win)
  end

  render.render()

  vim.schedule(function()
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      return
    end
    if #S.items == 0 then
      return
    end
    -- If <CR> passed a specific row, land there; otherwise ensure cursor stays in the tree.
    local desired = target_row or api.nvim_win_get_cursor(S.win)[1]
    local row = math.max(search_ui.line_for_item(1), math.min(desired, search_ui.line_for_item(#S.items)))
    pcall(api.nvim_win_set_cursor, S.win, { row, 0 })
  end)
end

function M.on_items_updated()
  if not S.search_active then
    return
  end
  if not (S.buf and api.nvim_buf_is_valid(S.buf)) then
    return
  end

  S.items = score_and_sort(S.items, S.filter)
  clamp_cursor()
  render._paint_items_only()
  render.paint_header()
  paint_match_layer()

  if S.search_win and api.nvim_win_is_valid(S.search_win) then
    local col = #ICON_PREFIX + #(S.filter or "")
    if focus_search_window() then
      pcall(api.nvim_win_set_cursor, S.search_win, { search_ui.INPUT_LNUM, col })
      vim.cmd("startinsert!")
    end
  end
end

-- ── setup: attach autocmds and buffer-local keymaps ──────────────────────

function M.setup(buf)
  local bopts = { buffer = buf, silent = true, noremap = true }

  -- Live filter: rebuild tree on every keystroke in the search bar
  api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if not S.search_active then
        return
      end
      if not (S.search_win and api.nvim_win_is_valid(S.search_win)) then
        return
      end
      if api.nvim_get_current_win() ~= S.search_win then
        return
      end
      if api.nvim_win_get_cursor(S.search_win)[1] ~= search_ui.INPUT_LNUM then
        return
      end
      local raw = api.nvim_buf_get_lines(buf, search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false)[1] or ""
      local t = strip_prefix(raw)
      S.filter = t ~= "" and t or nil
      rebuild_items()
    end,
  })

  -- InsertLeave: commit or discard the filter and land cursor on chosen result
  api.nvim_create_autocmd("InsertLeave", {
    buffer = buf,
    callback = vim.schedule_wrap(function()
      if not S.search_active then
        return
      end
      local target_row = S._post_search_row
      S._post_search_row = nil
      deactivate(S._search_clear_on_leave, target_row)
      S._search_clear_on_leave = false
    end),
  })

  -- ── Block completion popups ───────────────────────────────────────────
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

  -- ── <CR>: confirm filter and land cursor on selected result ──────────
  vim.keymap.set("i", "<CR>", function()
    if not S.search_active then
      return
    end
    S._search_clear_on_leave = false
    -- Communicate the target tree line to the InsertLeave handler.
    local idx = S._search_cursor or 0
    S._post_search_row = idx > 0 and search_ui.line_for_item(idx) or nil
    vim.cmd("stopinsert")
  end, bopts)

  -- ── <Esc> / <C-c>: discard filter ───────────────────────────────────
  local function discard_search()
    if not S.search_active then
      return
    end
    S._search_clear_on_leave = true
    vim.cmd("stopinsert")
  end
  vim.keymap.set("i", "<Esc>", discard_search, bopts)
  vim.keymap.set("i", "<C-c>", discard_search, bopts)

  -- ── <C-u> / <C-l>: wipe filter text, stay in insert ─────────────────
  local function wipe_filter()
    if not S.search_active then
      return
    end
    api.nvim_buf_set_lines(buf, search_ui.INPUT_ROW, search_ui.INPUT_ROW + 1, false, { search_ui.line_text("") })
    S.filter = nil
    S._search_cursor = 0
    api.nvim_win_set_cursor(S.search_win, { search_ui.INPUT_LNUM, #ICON_PREFIX })
    render.paint_header()
    rebuild_items()
  end
  vim.keymap.set("i", "<C-u>", wipe_filter, bopts)
  vim.keymap.set("i", "<C-l>", wipe_filter, bopts)

  -- ── <BS>: block deletion into the icon prefix zone ───────────────────
  vim.keymap.set("i", "<BS>", function()
    if not S.search_active then
      return "<BS>"
    end
    local col = api.nvim_win_get_cursor(S.search_win)[2]
    if col <= #ICON_PREFIX then
      return ""
    end
    return "<BS>"
  end, { buffer = buf, silent = true, noremap = true, expr = true })

  -- ── <Home> / <C-a>: jump to start of filter text ─────────────────────
  local function to_filter_start()
    if not S.search_active then
      return
    end
    api.nvim_win_set_cursor(S.search_win, { search_ui.INPUT_LNUM, #ICON_PREFIX })
  end
  vim.keymap.set("i", "<Home>", to_filter_start, bopts)
  vim.keymap.set("i", "<C-a>", to_filter_start, bopts)

  -- ── Clipboard paste ───────────────────────────────────────────────────
  vim.keymap.set("i", "<C-v>", paste_from_clipboard, bopts)
  vim.keymap.set("i", "<S-Insert>", paste_from_clipboard, bopts)

  -- ── <C-j> / <C-n> / <Down>: move result cursor down ──────────────────
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

  -- ── <C-k> / <C-p> / <Up>: move result cursor up ──────────────────────
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
    if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
      pcall(api.nvim_set_option_value, "modifiable", false, { buf = S.search_buf })
    end
    if S.buf and api.nvim_buf_is_valid(S.buf) then
      api.nvim_buf_clear_namespace(S.buf, S.match_ns, 0, -1)
    end
  end
end

function M.clear()
  S.filter = nil
  S.search_active = false
  S._search_cursor = nil
  if S.search_buf and api.nvim_buf_is_valid(S.search_buf) then
    pcall(api.nvim_set_option_value, "modifiable", false, { buf = S.search_buf })
  end
  if S.buf and api.nvim_buf_is_valid(S.buf) then
    api.nvim_buf_clear_namespace(S.buf, S.match_ns, 0, -1)
  end
  render.render()
end

return M
