-- window.lua
-- Grouped picker + preview float lifecycle for the code_action plugin.
--
-- New in this version:
--   • next_item_row fixed for large delta (C-d / C-u no longer skip items)
--   • text_preview truncation uses display width, not byte length
--   • is_open crash-recovery via M.reset()
--   • Redundant buffer delete removed from close_preview (bufhidden handles it)
--   • strwidth replaces opaque dw alias
--   • build_rows precomputes row→item-position map (O(1) status updates)
--   • Diff preview mode (toggle with d) using vim.text.diff() + scratch buffer
--   • Live filter float (/ to open, type to narrow, <CR> to confirm)
--   • Numeric shortcuts 1-9 jump directly to the Nth visible action
--   • <Tab> / <S-Tab> as additional nav aliases
--   • Mouse: double-click to apply, scroll-wheel to navigate
--   • Configurable winblend, width caps, and all keymaps via opts.config
--   • configure_float accepts winblend from config

local highlights = require("custom.code_action.highlight")
local kinds = require("custom.code_action.kinds")
local lsp = require("custom.code_action.lsp")

local M = {}
local HL = highlights.HL
local NS = highlights.NS

-- Module-level open guard. Reset with M.reset() if an error leaves it stuck.
local is_open = false

local GROUPS = {
  { key = "quickfix", label = "Quick Fixes" },
  { key = "refactor", label = "Refactors" },
  { key = "source", label = "Source Actions" },
  { key = "other", label = "Other Actions" },
}

-- ── Small utilities ───────────────────────────────────────────────────────────

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

---Display-cell width of string s (handles multi-byte / wide chars correctly).
local function strwidth(s)
  return vim.fn.strdisplaywidth(s)
end

local function classify(item)
  local kind = (item.action.kind or ""):lower()
  if vim.startswith(kind, "quickfix") then
    return "quickfix"
  end
  if vim.startswith(kind, "refactor") then
    return "refactor"
  end
  if vim.startswith(kind, "source") then
    return "source"
  end
  return "other"
end

local function clean_title(action)
  return (action.title or "Code Action"):gsub("[\r\n]", " ")
end

local function right_badges(item)
  local badges = {}
  if item.action.isPreferred then
    table.insert(badges, { "★", HL.Preferred })
  end
  if item.client and item.client.name then
    table.insert(badges, { item.client.name, highlights.source_hl(item.client.name) })
  end
  if item.action.disabled then
    table.insert(badges, { "disabled", HL.Disabled })
  end
  return badges
end

-- ── Row building ──────────────────────────────────────────────────────────────

---Build grouped, sorted display rows from a flat item list.
---Returns the row list, a row-index→item-position lookup, and the total item
---count.  The lookup enables O(1) status-line updates.
---@param items_list table[]
---@return table[], table<integer,integer>, integer
local function build_rows(items_list)
  local grouped = { quickfix = {}, refactor = {}, source = {}, other = {} }

  for _, item in ipairs(items_list) do
    table.insert(grouped[classify(item)], item)
  end

  for _, bucket in pairs(grouped) do
    table.sort(bucket, function(a, b)
      if a.action.isPreferred ~= b.action.isPreferred then
        return a.action.isPreferred == true
      end
      return clean_title(a.action) < clean_title(b.action)
    end)
  end

  local rows = {}
  local row_item_pos = {} -- row_index (1-based) → item position (1-based)
  local item_pos = 0

  for _, group in ipairs(GROUPS) do
    local bucket = grouped[group.key]
    if #bucket > 0 then
      table.insert(rows, { kind = "header", label = group.label, count = #bucket })
      for _, item in ipairs(bucket) do
        item_pos = item_pos + 1
        table.insert(rows, { kind = "item", item = item })
        row_item_pos[#rows] = item_pos
      end
    end
  end

  return rows, row_item_pos, item_pos
end

---Index of the first item row (skipping headers).
local function first_item_row(row_list)
  for i, row in ipairs(row_list) do
    if row.kind == "item" then
      return i
    end
  end
  return 1
end

---Index of the last item row.
local function last_item_row(row_list)
  for i = #row_list, 1, -1 do
    if row_list[i].kind == "item" then
      return i
    end
  end
  return 1
end

---Move from `start` by `delta` rows, then snap to the nearest item in the
---direction of travel.  Works correctly for both delta=1 (normal j/k) and
---large deltas (half-page <C-d>/<C-u>) without overshooting.
---@param row_list table[]
---@param start    integer
---@param delta    integer  positive = down, negative = up
---@return integer
local function next_item_row(row_list, start, delta)
  if #row_list == 0 then
    return 1
  end
  local dir = delta >= 0 and 1 or -1
  local target = clamp(start + delta, 1, #row_list)

  -- Walk from the target in the direction of travel to find an item row.
  for i = target, dir > 0 and #row_list or 1, dir do
    if row_list[i].kind == "item" then
      return i
    end
  end
  -- If nothing found that way, walk the other direction (boundary case).
  for i = target, dir > 0 and 1 or #row_list, -dir do
    if row_list[i].kind == "item" then
      return i
    end
  end

  return start
end

-- ── Width estimation ──────────────────────────────────────────────────────────

local function estimate_width(items, cfg_picker)
  local max_width = 0
  for _, item in ipairs(items) do
    local right = 0
    for _, badge in ipairs(right_badges(item)) do
      right = right + strwidth(badge[1]) + 1
    end
    max_width = math.max(max_width, 4 + kinds.symbol_width() + strwidth(clean_title(item.action)) + right + 6)
  end
  for _, group in ipairs(GROUPS) do
    max_width = math.max(max_width, strwidth(group.label) + 8)
  end
  local min_w = cfg_picker and cfg_picker.min_width or 48
  local max_w = math.max(min_w, math.floor(vim.o.columns * (cfg_picker and cfg_picker.max_width_pct or 0.50)))
  return clamp(max_width, min_w, max_w)
end

-- ── Text helpers ──────────────────────────────────────────────────────────────

local function range_label(range)
  if not range then
    return "?"
  end
  local s = range.start or range["start"]
  local e = range["end"]
  return string.format("L%d:%d-L%d:%d", s.line + 1, s.character + 1, e.line + 1, e.character + 1)
end

---Truncate preview text to ≤90 display cells (not bytes).
local function text_preview(text)
  local normalized = tostring(text or ""):gsub("\r", ""):gsub("\n", "\\n")
  if normalized == "" then
    return '""'
  end
  if strwidth(normalized) > 90 then
    normalized = vim.fn.strcharpart(normalized, 0, 87) .. "..."
  end
  return normalized
end

local function append_kv(lines, spans, label, value)
  table.insert(lines, label .. value)
  table.insert(spans, { row = #lines - 1, label_end = #label, value_start = #label })
end

local function summarize_workspace_edit(edit)
  local lines, spans = {}, {}

  local function add_change(file, edits)
    table.insert(lines, file)
    table.insert(spans, { row = #lines - 1, file = true })
    local limit = math.min(#edits, 6)
    for idx = 1, limit do
      local entry = edits[idx]
      table.insert(lines, ("  • %s -> %s"):format(range_label(entry.range), text_preview(entry.newText)))
    end
    if #edits > limit then
      table.insert(lines, ("  • ... %d more edit(s)"):format(#edits - limit))
    end
  end

  if edit.changes then
    local uris = vim.tbl_keys(edit.changes)
    table.sort(uris)
    for _, uri in ipairs(uris) do
      add_change(vim.fn.fnamemodify(vim.uri_to_fname(uri), ":~:."), edit.changes[uri])
    end
  elseif edit.documentChanges then
    for _, change in ipairs(edit.documentChanges) do
      if change.kind == "create" then
        table.insert(lines, ("Create %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")))
      elseif change.kind == "rename" then
        table.insert(
          lines,
          ("Rename %s -> %s"):format(
            vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":~:."),
            vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":~:.")
          )
        )
      elseif change.kind == "delete" then
        table.insert(lines, ("Delete %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")))
      elseif change.textDocument and change.edits then
        add_change(vim.fn.fnamemodify(vim.uri_to_fname(change.textDocument.uri), ":~:."), change.edits)
      end
    end
  end

  return lines, spans
end

local function summary_preview_lines(action, item)
  local lines, spans = {}, {}

  append_kv(lines, spans, "Title: ", clean_title(action))
  append_kv(lines, spans, "Kind: ", action.kind or "none")
  append_kv(lines, spans, "Source: ", item.client and item.client.name or "unknown")
  append_kv(lines, spans, "Preferred: ", action.isPreferred and "yes" or "no")

  if action.disabled then
    append_kv(lines, spans, "Disabled: ", type(action.disabled) == "table" and action.disabled.reason or "yes")
  end

  if action.command then
    local cmd = type(action.command) == "table" and action.command.command or tostring(action.command)
    append_kv(lines, spans, "Command: ", cmd or "unknown")
  end

  if action.data ~= nil then
    append_kv(lines, spans, "Resolve Data: ", "available")
  end

  if action.edit then
    table.insert(lines, "")
    table.insert(lines, "Workspace Edit")
    table.insert(spans, { row = #lines - 1, file = true })
    local edit_lines, edit_spans = summarize_workspace_edit(action.edit)
    local base = #lines
    vim.list_extend(lines, edit_lines)
    for _, span in ipairs(edit_spans) do
      table.insert(spans, { row = base + span.row, file = span.file })
    end
  elseif not action.command then
    table.insert(lines, "")
    table.insert(lines, "No edit or command payload was provided.")
    table.insert(lines, "This action is likely resolved lazily by the server.")
  end

  return lines, spans
end

-- ── Diff preview ──────────────────────────────────────────────────────────────

---Compute a unified diff for a resolved action's workspace edit.
---Returns a list of diff lines (with --- / +++ headers per file), or nil when
---no textual diff is available (command-only, create, rename, delete, etc.).
---@param action table  resolved LSP CodeAction
---@param client table|nil
---@return string[]|nil
local function compute_diff_lines(action, client)
  if not action or not action.edit then
    return nil
  end

  local encoding = client and client.offset_encoding or "utf-8"
  local result = {}

  local function diff_uri(uri, text_edits)
    local fname = vim.uri_to_fname(uri)
    local rel = vim.fn.fnamemodify(fname, ":~:.")

    -- Prefer the live buffer; fall back to reading from disk.
    local orig = {}
    local existing_buf = vim.fn.bufnr(fname)
    if existing_buf ~= -1 and vim.api.nvim_buf_is_loaded(existing_buf) then
      orig = vim.api.nvim_buf_get_lines(existing_buf, 0, -1, false)
    else
      local ok, file_lines = pcall(vim.fn.readfile, fname)
      if ok then
        orig = file_lines
      end
    end

    -- Apply the edits to a throw-away scratch buffer.
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, orig)
    local ok2 = pcall(vim.lsp.util.apply_text_edits, text_edits, scratch, encoding)
    if not ok2 then
      pcall(vim.api.nvim_buf_delete, scratch, { force = true })
      return
    end
    local modified = vim.api.nvim_buf_get_lines(scratch, 0, -1, false)
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })

    local a_text = table.concat(orig, "\n") .. "\n"
    local b_text = table.concat(modified, "\n") .. "\n"
    if a_text == b_text then
      return
    end

    local diff_str = vim.text.diff(a_text, b_text, {
      result_type = "unified",
      algorithm = "minimal",
    })

    if diff_str and diff_str ~= "" then
      table.insert(result, ("--- a/%s"):format(rel))
      table.insert(result, ("+++ b/%s"):format(rel))
      for _, line in ipairs(vim.split(diff_str, "\n", { plain = true })) do
        table.insert(result, line)
      end
    end
  end

  local edit = action.edit
  if edit.changes then
    local uris = vim.tbl_keys(edit.changes)
    table.sort(uris)
    for _, uri in ipairs(uris) do
      diff_uri(uri, edit.changes[uri])
    end
  elseif edit.documentChanges then
    for _, change in ipairs(edit.documentChanges) do
      if change.textDocument and change.edits then
        diff_uri(change.textDocument.uri, change.edits)
      elseif change.kind == "create" then
        table.insert(result, ("(create) %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")))
      elseif change.kind == "rename" then
        table.insert(
          result,
          ("(rename) %s  →  %s"):format(
            vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":~:."),
            vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":~:.")
          )
        )
      elseif change.kind == "delete" then
        table.insert(result, ("(delete) %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")))
      end
    end
  end

  return #result > 0 and result or nil
end

-- ── Float helpers ─────────────────────────────────────────────────────────────

local function configure_float(win, opts)
  vim.wo[win].cursorline = opts.cursorline or false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = opts.wrap or false
  vim.wo[win].scrolloff = 0
  vim.wo[win].winblend = opts.winblend or 0
  vim.wo[win].winhighlight = table.concat({
    "Normal:" .. HL.Normal,
    "FloatBorder:" .. HL.Border,
    "FloatTitle:" .. HL.Title,
    "FloatFooter:" .. HL.Footer,
    "CursorLine:" .. HL.CursorLine,
  }, ",")
end

local function place_picker(width, height, source_win, source_cursor)
  local sp = vim.fn.screenpos(source_win, source_cursor[1], source_cursor[2] + 1)
  local srow = (sp.row > 0 and sp.row or 1) - 1
  local scol = (sp.col > 0 and sp.col or 1) - 1

  local row = clamp(srow + 1, 0, math.max(vim.o.lines - height - 2, 0))
  local col = scol + 2
  if col + width + 2 > vim.o.columns then
    col = math.max(scol - width - 2, 0)
  end

  return row, col
end

local function place_preview(picker_row, picker_col, picker_width, picker_height, preview_width)
  local right_col = picker_col + picker_width + 3
  if right_col + preview_width + 2 <= vim.o.columns then
    return picker_row, right_col
  end

  local below_row = picker_row + picker_height + 2
  if below_row + picker_height + 2 <= vim.o.lines then
    return below_row, picker_col
  end

  return clamp(picker_row, 0, math.max(vim.o.lines - picker_height - 2, 0)),
    clamp(picker_col - preview_width - 3, 0, math.max(vim.o.columns - preview_width - 2, 0))
end

local function set_statusline(win, text)
  vim.api.nvim_set_option_value("statusline", " " .. text .. " ", { scope = "local", win = win })
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

---Reset the is_open guard.  Call if an unhandled error leaves the menu stuck.
function M.reset()
  is_open = false
end

-- ── Main open function ────────────────────────────────────────────────────────

function M.open(items, source_win, source_buf, source_cursor, opts)
  opts = opts or {}
  local cfg = opts.config or {}
  local cfg_picker = cfg.picker or {}
  local cfg_preview = cfg.preview or {}
  local km = cfg.keymaps or {}

  -- ── Guards ────────────────────────────────────────────────────────────────

  if is_open then
    vim.notify("Code action menu is already open", vim.log.levels.WARN, { title = "Code Actions" })
    return
  end

  if vim.tbl_isempty(items) then
    vim.notify("No code actions available", vim.log.levels.INFO, { title = "Code Actions" })
    return
  end

  is_open = true

  -- ── State ─────────────────────────────────────────────────────────────────

  local all_items = items
  local all_rows, all_row_item_pos, all_item_count = build_rows(all_items)
  local rows = all_rows
  local row_item_pos = all_row_item_pos
  local filtered_count = all_item_count
  local filter_query = ""

  local preview = { buf = nil, win = nil, open = false }
  local preview_mode = cfg_preview.show_diff and "diff" or "summary" -- "summary" | "diff"
  local closed = false

  local filter_win = nil -- live-filter input float
  local filter_buf_ref = nil

  -- ── Geometry ──────────────────────────────────────────────────────────────

  local picker_width = estimate_width(all_items, cfg_picker)
  local picker_height = clamp(#all_rows, 6, math.max(6, math.floor(vim.o.lines * (cfg_picker.max_height_pct or 0.45))))
  local preview_width = clamp(
    math.floor(vim.o.columns * (cfg_preview.width_pct or 0.36)),
    cfg_preview.min_width or 38,
    cfg_preview.max_width or 72
  )
  local picker_row, picker_col = place_picker(picker_width, picker_height, source_win, source_cursor)

  -- ── Picker buffer + window ────────────────────────────────────────────────

  local picker_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[picker_buf].bufhidden = "wipe"
  vim.bo[picker_buf].buftype = "nofile"
  vim.bo[picker_buf].swapfile = false
  vim.bo[picker_buf].filetype = "codeactionmenu"

  local picker_win = vim.api.nvim_open_win(picker_buf, true, {
    relative = "editor",
    row = picker_row,
    col = picker_col,
    width = picker_width,
    height = picker_height,
    style = "minimal",
    border = "rounded",
    title = " 󰌶 Code Actions ",
    title_pos = "left",
    footer = " <CR> apply  K preview  / filter  q close ",
    footer_pos = "center",
    zindex = 60,
    noautocmd = true,
  })
  configure_float(picker_win, { cursorline = true, winblend = cfg_picker.winblend or 0 })

  -- ── Filter ────────────────────────────────────────────────────────────────

  ---Apply a filter query to the item list and rebuild rows.
  local function apply_filter(query)
    filter_query = query or ""
    if filter_query == "" then
      rows, row_item_pos, filtered_count = all_rows, all_row_item_pos, all_item_count
    else
      local q = filter_query:lower()
      local filtered = vim.tbl_filter(function(it)
        local title = clean_title(it.action):lower()
        local kind = (it.action.kind or ""):lower()
        local source = (it.client and it.client.name or ""):lower()
        return title:find(q, 1, true) or kind:find(q, 1, true) or source:find(q, 1, true)
      end, all_items)
      rows, row_item_pos, filtered_count = build_rows(filtered)
    end
  end

  -- ── Close helpers ─────────────────────────────────────────────────────────

  local function restore_focus()
    if vim.api.nvim_win_is_valid(source_win) then
      vim.api.nvim_set_current_win(source_win)
      if vim.api.nvim_buf_is_valid(source_buf) then
        local line_count = vim.api.nvim_buf_line_count(source_buf)
        local line = clamp(source_cursor[1], 1, math.max(line_count, 1))
        local row_text = vim.api.nvim_buf_get_lines(source_buf, line - 1, line, false)[1] or ""
        local col = clamp(source_cursor[2], 0, math.max(#row_text - 1, 0))
        pcall(vim.api.nvim_win_set_cursor, source_win, { line, col })
      end
    end
  end

  local function close_preview()
    preview.open = false
    -- bufhidden = "wipe" already cleans up the buffer when the window closes;
    -- we only need to close the window here.
    if preview.win and vim.api.nvim_win_is_valid(preview.win) then
      pcall(vim.api.nvim_win_close, preview.win, true)
    end
    preview.win = nil
    preview.buf = nil
  end

  local function close()
    if closed then
      return
    end
    closed = true
    is_open = false
    -- Close the filter input float if open.
    if filter_win and vim.api.nvim_win_is_valid(filter_win) then
      pcall(vim.api.nvim_win_close, filter_win, true)
      filter_win = nil
      filter_buf_ref = nil
    end
    close_preview()
    if vim.api.nvim_win_is_valid(picker_win) then
      pcall(vim.api.nvim_win_close, picker_win, true)
    end
    restore_focus()
  end

  -- ── Picker rendering ──────────────────────────────────────────────────────

  local function render_picker()
    vim.api.nvim_buf_clear_namespace(picker_buf, NS, 0, -1)
    local lines = {}

    if #rows == 0 then
      table.insert(lines, "  No actions match the filter.")
      vim.bo[picker_buf].modifiable = true
      vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
      vim.bo[picker_buf].modifiable = false
      vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Disabled, 0, 0, -1)
      return
    end

    for _, row in ipairs(rows) do
      if row.kind == "header" then
        table.insert(lines, " " .. row.label)
      else
        table.insert(lines, (" %s %s"):format(kinds.get(row.item.action.kind), clean_title(row.item.action)))
      end
    end

    vim.bo[picker_buf].modifiable = true
    vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
    vim.bo[picker_buf].modifiable = false

    for idx, row in ipairs(rows) do
      local rownr = idx - 1
      if row.kind == "header" then
        vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Header, rownr, 0, -1)
        vim.api.nvim_buf_set_extmark(picker_buf, NS, rownr, 0, {
          virt_text = { { ("(%d)"):format(row.count), HL.HeaderCount } },
          virt_text_pos = "right_align",
        })
      else
        local icon = kinds.get(row.item.action.kind)
        -- nvim_buf_add_highlight takes byte offsets; #icon gives the correct
        -- byte length of the (possibly multi-byte) UTF-8 glyph.
        vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Kind, rownr, 1, 1 + #icon)
        if row.item.action.disabled then
          vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Disabled, rownr, 0, -1)
        end
        -- Highlight filter match in item title when a query is active.
        if filter_query ~= "" then
          local q = filter_query:lower()
          local title = clean_title(row.item.action):lower()
          local ms, me = title:find(q, 1, true)
          if ms then
            -- Offset by leading space + icon + space (byte positions).
            local prefix = 1 + #icon + 1
            vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.FilterMatch, rownr, prefix + ms - 1, prefix + me)
          end
        end
        local badges = right_badges(row.item)
        if #badges > 0 then
          local virt = {}
          for _, badge in ipairs(badges) do
            table.insert(virt, { badge[1] .. " ", badge[2] })
          end
          vim.api.nvim_buf_set_extmark(picker_buf, NS, rownr, 0, {
            virt_text = virt,
            virt_text_pos = "right_align",
          })
        end
      end
    end
  end

  -- ── Cursor / item helpers ─────────────────────────────────────────────────

  local function current_row_index()
    if #rows == 0 then
      return 1
    end
    if not vim.api.nvim_win_is_valid(picker_win) then
      return first_item_row(rows)
    end
    local index = clamp(vim.api.nvim_win_get_cursor(picker_win)[1], 1, #rows)
    if rows[index] and rows[index].kind == "header" then
      index = next_item_row(rows, index, 1)
    end
    return index
  end

  local function current_item()
    local index = current_row_index()
    local row = rows[index]
    return row and row.item or nil, index
  end

  local function update_picker_status()
    if not vim.api.nvim_win_is_valid(picker_win) then
      return
    end
    local index = current_row_index()
    local row = rows[index]
    if not row or row.kind ~= "item" then
      return
    end
    local item = row.item
    local pos = row_item_pos[index] or 0
    local filter_tag = filter_query ~= "" and ("  [/%s %d/%d]"):format(filter_query, filtered_count, all_item_count)
      or ""
    local mode_tag = preview.open and (" [%s]"):format(preview_mode) or ""
    set_statusline(
      picker_win,
      ("%s  %d/%d%s%s"):format(item.client and item.client.name or "LSP", pos, filtered_count, filter_tag, mode_tag)
    )
  end

  ---Return the row index of the Nth item (1-based) in the current filtered rows.
  local function item_row_at_pos(n)
    local count = 0
    for i, row in ipairs(rows) do
      if row.kind == "item" then
        count = count + 1
        if count == n then
          return i
        end
      end
    end
    return nil
  end

  -- ── Preview rendering ─────────────────────────────────────────────────────

  local function ensure_preview()
    if preview.open and preview.win and vim.api.nvim_win_is_valid(preview.win) then
      return
    end

    preview.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[preview.buf].bufhidden = "wipe"
    vim.bo[preview.buf].buftype = "nofile"
    vim.bo[preview.buf].swapfile = false
    vim.bo[preview.buf].filetype = "codeactionpreview"

    local row, col = place_preview(picker_row, picker_col, picker_width, picker_height, preview_width)
    preview.win = vim.api.nvim_open_win(preview.buf, false, {
      relative = "editor",
      row = row,
      col = col,
      width = preview_width,
      height = picker_height,
      style = "minimal",
      border = "rounded",
      title = " Preview ",
      title_pos = "left",
      footer = " K toggle  d diff/summary  <CR> apply ",
      footer_pos = "center",
      zindex = 59,
      noautocmd = true,
    })
    configure_float(preview.win, { wrap = true, winblend = cfg_preview.winblend or 0 })
    preview.open = true
  end

  ---Render lines into the preview buffer.
  ---@param lines    string[]
  ---@param spans    table[]|nil  highlight spans (used in summary mode only)
  ---@param status   string       statusline text
  ---@param ft       string|nil   filetype for syntax highlighting; nil = summary
  local function render_preview_content(lines, spans, status, ft)
    if not preview.open then
      return
    end

    vim.bo[preview.buf].modifiable = true
    vim.api.nvim_buf_set_lines(preview.buf, 0, -1, false, lines)
    vim.bo[preview.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(preview.buf, NS, 0, -1)

    -- Set filetype: "diff" triggers built-in diff syntax; summary uses manual HL.
    pcall(function()
      vim.bo[preview.buf].filetype = ft or "codeactionpreview"
    end)

    -- Apply manual highlights only in summary mode (diff syntax handles its own).
    if not ft then
      for _, span in ipairs(spans or {}) do
        if span.file then
          vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.Header, span.row, 0, -1)
        elseif span.label_end then
          vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.PreviewLabel, span.row, 0, span.label_end)
          vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.PreviewValue, span.row, span.value_start, -1)
        end
      end
    end

    set_statusline(preview.win, status)
  end

  local function update_preview(force)
    if not preview.open and not force then
      return
    end
    local item = current_item()
    if not item then
      return
    end

    ensure_preview()
    render_preview_content({ "Loading preview…" }, {}, " Preview ", nil)

    lsp.resolve_for_preview(item, function(err, action)
      if closed or not preview.open then
        return
      end
      if err then
        render_preview_content({ err }, {}, " Preview Error ", nil)
        return
      end

      if preview_mode == "diff" then
        local diff_lines = compute_diff_lines(action, item.client)
        if diff_lines then
          render_preview_content(diff_lines, {}, " Diff Preview  (d: summary) ", "diff")
        else
          render_preview_content({
            "",
            "  No diff available for this action.",
            "",
            "  This action may:",
            "  • Use lazy resolution (no edit payload yet)",
            "  • Execute a server command only",
            "  • Perform a file create / rename / delete",
          }, {}, " Diff Preview  (d: summary) ", nil)
        end
      else
        local lines, spans = summary_preview_lines(action, item)
        render_preview_content(lines, spans, " Summary Preview  (d: diff) ", nil)
      end
    end)
  end

  -- ── Actions ───────────────────────────────────────────────────────────────

  local function execute_selected()
    local item = current_item()
    if not item then
      return
    end
    close()
    vim.schedule(function()
      lsp.apply(item)
    end)
  end

  local function nav(delta)
    if not vim.api.nvim_win_is_valid(picker_win) then
      return
    end
    local current = current_row_index()
    local target = next_item_row(rows, current, delta)
    vim.api.nvim_win_set_cursor(picker_win, { target, 0 })
    update_picker_status()
    if preview.open then
      update_preview(false)
    end
  end

  local function toggle_preview()
    if preview.open then
      close_preview()
      update_picker_status()
    else
      update_preview(true)
    end
  end

  local function toggle_preview_mode()
    preview_mode = preview_mode == "summary" and "diff" or "summary"
    if preview.open then
      update_preview(false)
    end
    update_picker_status()
  end

  local function go_to_item(n)
    local target = item_row_at_pos(n)
    if target then
      vim.api.nvim_win_set_cursor(picker_win, { target, 0 })
      update_picker_status()
      if preview.open then
        update_preview(false)
      end
    end
  end

  -- ── Filter input float ────────────────────────────────────────────────────

  local function open_filter_input()
    -- If filter is already open, just give it focus.
    if filter_win and vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_set_current_win(filter_win)
      vim.cmd("startinsert!")
      return
    end

    filter_buf_ref = vim.api.nvim_create_buf(false, true)
    vim.bo[filter_buf_ref].bufhidden = "wipe"
    vim.bo[filter_buf_ref].buftype = "nofile"
    -- Pre-fill with current query so the user can refine it.
    if filter_query ~= "" then
      vim.api.nvim_buf_set_lines(filter_buf_ref, 0, -1, false, { filter_query })
    end

    local f_row = picker_row + picker_height + 2
    if f_row + 3 > vim.o.lines then
      f_row = math.max(0, picker_row - 3)
    end

    filter_win = vim.api.nvim_open_win(filter_buf_ref, true, {
      relative = "editor",
      row = f_row,
      col = picker_col,
      width = picker_width,
      height = 1,
      style = "minimal",
      border = "rounded",
      title = " / Filter ",
      title_pos = "left",
      footer = " <CR> confirm  <Esc> cancel ",
      footer_pos = "center",
      zindex = 65,
      noautocmd = true,
    })
    configure_float(filter_win, { winblend = cfg_picker.winblend or 0 })
    vim.cmd("startinsert!")

    local fopts = { buffer = filter_buf_ref, silent = true, nowait = true }

    local function commit_filter()
      local query = vim.api.nvim_buf_get_lines(filter_buf_ref, 0, -1, false)[1] or ""
      vim.cmd("stopinsert")
      if vim.api.nvim_win_is_valid(filter_win) then
        pcall(vim.api.nvim_win_close, filter_win, true)
      end
      filter_win = nil
      filter_buf_ref = nil
      vim.api.nvim_set_current_win(picker_win)
      apply_filter(query)
      render_picker()
      local target = first_item_row(rows)
      if #rows > 0 then
        vim.api.nvim_win_set_cursor(picker_win, { target, 0 })
      end
      update_picker_status()
      if preview.open then
        update_preview(false)
      end
    end

    local function cancel_filter()
      vim.cmd("stopinsert")
      if vim.api.nvim_win_is_valid(filter_win) then
        pcall(vim.api.nvim_win_close, filter_win, true)
      end
      filter_win = nil
      filter_buf_ref = nil
      if vim.api.nvim_win_is_valid(picker_win) then
        vim.api.nvim_set_current_win(picker_win)
      end
    end

    vim.keymap.set("i", "<CR>", commit_filter, fopts)
    vim.keymap.set("i", "<Esc>", cancel_filter, fopts)
    vim.keymap.set("n", "<Esc>", cancel_filter, fopts)
    vim.keymap.set("n", "q", cancel_filter, fopts)

    -- Live update: re-filter and re-render the picker as the user types.
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = filter_buf_ref,
      callback = function()
        if closed then
          return
        end
        local query = vim.api.nvim_buf_get_lines(filter_buf_ref, 0, -1, false)[1] or ""
        apply_filter(query)
        render_picker()
        if #rows > 0 then
          vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
          update_picker_status()
          if preview.open then
            update_preview(false)
          end
        end
      end,
    })
  end

  -- ── Initial render + cursor ───────────────────────────────────────────────

  render_picker()
  vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
  update_picker_status()

  -- ── Keymaps ───────────────────────────────────────────────────────────────

  local map_opts = { buffer = picker_buf, silent = true, nowait = true }
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, map_opts)
  end
  ---Register one or multiple keys for the same action.
  local function map_all(keys_or_key, rhs)
    local keys = type(keys_or_key) == "table" and keys_or_key or { keys_or_key }
    for _, k in ipairs(keys) do
      map(k, rhs)
    end
  end
  ---Read a keymap value from cfg, falling back to the provided default.
  local function km_val(key, default)
    local v = km[key]
    return (v ~= nil) and v or default
  end

  map_all(km_val("apply", "<CR>"), execute_selected)
  map_all(km_val("close", { "<Esc>", "q" }), close)
  map_all(km_val("preview", { "K", "p" }), toggle_preview)
  map_all(km_val("diff_mode", "d"), toggle_preview_mode)
  map_all(km_val("nav_down", { "j", "<Down>", "<C-n>", "<Tab>" }), function()
    nav(1)
  end)
  map_all(km_val("nav_up", { "k", "<Up>", "<C-p>", "<S-Tab>" }), function()
    nav(-1)
  end)
  map_all(km_val("go_first", "gg"), function()
    if #rows == 0 then
      return
    end
    vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
    update_picker_status()
    if preview.open then
      update_preview(false)
    end
  end)
  map_all(km_val("go_last", "G"), function()
    if #rows == 0 then
      return
    end
    vim.api.nvim_win_set_cursor(picker_win, { last_item_row(rows), 0 })
    update_picker_status()
    if preview.open then
      update_preview(false)
    end
  end)
  map_all(km_val("page_down", "<C-d>"), function()
    nav(math.max(1, math.floor(picker_height / 2)))
  end)
  map_all(km_val("page_up", "<C-u>"), function()
    nav(-math.max(1, math.floor(picker_height / 2)))
  end)
  map_all(km_val("filter", "/"), open_filter_input)

  -- Numeric shortcuts: press 1-9 to jump directly to the Nth visible action.
  for n = 1, 9 do
    map(tostring(n), function()
      go_to_item(n)
    end)
  end

  -- Mouse support: double-click to apply, scroll-wheel to navigate.
  map("<2-LeftMouse>", execute_selected)
  map("<ScrollWheelDown>", function()
    nav(3)
  end)
  map("<ScrollWheelUp>", function()
    nav(-3)
  end)

  -- ── Autocmds ──────────────────────────────────────────────────────────────

  -- Snap cursor away from headers and keep status + preview in sync.
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = picker_buf,
    callback = function()
      if closed then
        return
      end
      local row = current_row_index()
      if #rows == 0 then
        return
      end
      local cur = vim.api.nvim_win_get_cursor(picker_win)
      if cur[1] ~= row then
        vim.api.nvim_win_set_cursor(picker_win, { row, 0 })
      end
      update_picker_status()
      if preview.open then
        update_preview(false)
      end
    end,
  })

  -- Close the picker when the source window closes.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(source_win),
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  -- Close the picker if its buffer is wiped externally.
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = picker_buf,
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  -- ── Auto-open preview ─────────────────────────────────────────────────────

  if opts.open_preview then
    update_preview(true)
  end
end

return M
