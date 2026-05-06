-- window.lua
-- Grouped picker + preview float lifecycle for the code_action plugin.
--
-- Neovim 0.12 modernisation:
--   • vim.lsp.get_clients (replaces deprecated buf_get_clients)
--   • vim.api.nvim_set_option_value (replaces nvim_win_set_option)
--   • vim.wo[win][opt] scoped writes
--   • vim.diagnostic.get (no legacy sign/namespace APIs)
--   • vim.text.diff for unified diffs
--   • Buffer-picker style preview (live diff in a real scratch buffer, tiny-code-action style)
--   • Inline diff highlights applied via extmarks (no 'diff' option quirks)
--   • Footer / title use custom.ui.window's native fields (0.10+)
--   • noautocmd = true on every float open to skip slow BufEnter handlers
--   • All win-scoped options via vim.wo[win] = value (0.11+ scoped API)

local highlights = require("custom.code_action.highlight")
local kinds = require("custom.code_action.kinds")
local lsp = require("custom.code_action.lsp")

local M = {}
local HL = highlights.HL
local NS = highlights.NS

local is_open = false

local GROUPS = {
  { key = "quickfix", label = "Quick Fixes" },
  { key = "refactor", label = "Refactors" },
  { key = "source", label = "Source Actions" },
  { key = "other", label = "Other Actions" },
}

-- ── Utilities ─────────────────────────────────────────────────────────────────

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

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
    badges[#badges + 1] = { "★", HL.Preferred }
  end
  if item.client and item.client.name then
    badges[#badges + 1] = { item.client.name, highlights.source_hl(item.client.name) }
  end
  if item.action.disabled then
    badges[#badges + 1] = { "disabled", HL.Disabled }
  end
  return badges
end

-- ── Row building ──────────────────────────────────────────────────────────────

---@return table[], table<integer,integer>, integer
local function build_rows(items_list)
  local grouped = { quickfix = {}, refactor = {}, source = {}, other = {} }

  for _, item in ipairs(items_list) do
    local bucket = grouped[classify(item)]
    bucket[#bucket + 1] = item
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
  local row_item_pos = {}
  local item_pos = 0

  for _, group in ipairs(GROUPS) do
    local bucket = grouped[group.key]
    if #bucket > 0 then
      rows[#rows + 1] = { kind = "header", label = group.label, count = #bucket }
      for _, item in ipairs(bucket) do
        item_pos = item_pos + 1
        rows[#rows + 1] = { kind = "item", item = item }
        row_item_pos[#rows] = item_pos
      end
    end
  end

  return rows, row_item_pos, item_pos
end

local function first_item_row(row_list)
  for i, row in ipairs(row_list) do
    if row.kind == "item" then
      return i
    end
  end
  return 1
end

local function last_item_row(row_list)
  for i = #row_list, 1, -1 do
    if row_list[i].kind == "item" then
      return i
    end
  end
  return 1
end

local function next_item_row(row_list, start, delta)
  if #row_list == 0 then
    return 1
  end
  local dir = delta >= 0 and 1 or -1
  local target = clamp(start + delta, 1, #row_list)
  for i = target, dir > 0 and #row_list or 1, dir do
    if row_list[i].kind == "item" then
      return i
    end
  end
  for i = target, dir > 0 and 1 or #row_list, -dir do
    if row_list[i].kind == "item" then
      return i
    end
  end
  return start
end

-- ── Width estimation ──────────────────────────────────────────────────────────

local function estimate_width(items, cfg_picker)
  local max_w = 0
  for _, item in ipairs(items) do
    local right = 0
    for _, badge in ipairs(right_badges(item)) do
      right = right + strwidth(badge[1]) + 1
    end
    max_w = math.max(max_w, 4 + kinds.symbol_width() + strwidth(clean_title(item.action)) + right + 6)
  end
  for _, group in ipairs(GROUPS) do
    max_w = math.max(max_w, strwidth(group.label) + 8)
  end
  local min_w = cfg_picker and cfg_picker.min_width or 48
  local cap = math.max(min_w, math.floor(vim.o.columns * (cfg_picker and cfg_picker.max_width_pct or 0.50)))
  return clamp(max_w, min_w, cap)
end

-- ── Text helpers ──────────────────────────────────────────────────────────────

local function range_label(range)
  if not range then
    return "?"
  end
  local s = range.start or range["start"]
  local e = range["end"]
  return ("L%d:%d-L%d:%d"):format(s.line + 1, s.character + 1, e.line + 1, e.character + 1)
end

local function text_preview(text)
  local n = tostring(text or ""):gsub("\r", ""):gsub("\n", "\\n")
  if n == "" then
    return '""'
  end
  if strwidth(n) > 90 then
    n = vim.fn.strcharpart(n, 0, 87) .. "..."
  end
  return n
end

local function detect_filetype(fname, contents)
  local ok, ft = pcall(vim.filetype.match, { filename = fname, contents = contents })
  if not ok or not ft or ft == "" then
    ft = vim.fn.fnamemodify(fname, ":e")
  end
  return ft ~= "" and ft or "text"
end

local function treesitter_lang_for_filetype(ft)
  if not ft or ft == "" or type(vim.treesitter) ~= "table" then
    return nil
  end
  if vim.treesitter.language and type(vim.treesitter.language.get_lang) == "function" then
    local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
    if ok and lang and lang ~= "" then
      return lang
    end
  end
  return ft
end

local function has_treesitter_parser(bufnr, lang)
  if not lang or lang == "" or type(vim.treesitter) ~= "table" then
    return false
  end
  local ok = pcall(vim.treesitter.get_parser, bufnr, lang)
  return ok
end

local function append_kv(lines, spans, label, value)
  lines[#lines + 1] = label .. value
  spans[#spans + 1] = { row = #lines - 1, label_end = #label, value_start = #label }
end

local function summarize_workspace_edit(edit)
  local lines, spans = {}, {}

  local function add_change(file, edits)
    lines[#lines + 1] = file
    spans[#spans + 1] = { row = #lines - 1, file = true }
    local limit = math.min(#edits, 6)
    for i = 1, limit do
      local entry = edits[i]
      lines[#lines + 1] = ("  • %s -> %s"):format(range_label(entry.range), text_preview(entry.newText))
    end
    if #edits > limit then
      lines[#lines + 1] = ("  • … %d more edit(s)"):format(#edits - limit)
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
        lines[#lines + 1] = ("Create %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:."))
      elseif change.kind == "rename" then
        lines[#lines + 1] = ("Rename %s → %s"):format(
          vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":~:."),
          vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":~:.")
        )
      elseif change.kind == "delete" then
        lines[#lines + 1] = ("Delete %s"):format(vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:."))
      elseif change.textDocument and change.edits then
        add_change(vim.fn.fnamemodify(vim.uri_to_fname(change.textDocument.uri), ":~:."), change.edits)
      end
    end
  end

  return lines, spans
end

local function summary_preview_lines(action, item)
  local lines, spans = {}, {}

  append_kv(lines, spans, "Title:     ", clean_title(action))
  append_kv(lines, spans, "Kind:      ", action.kind or "none")
  append_kv(lines, spans, "Source:    ", item.client and item.client.name or "unknown")
  append_kv(lines, spans, "Preferred: ", action.isPreferred and "yes" or "no")

  if action.disabled then
    append_kv(lines, spans, "Disabled:  ", type(action.disabled) == "table" and action.disabled.reason or "yes")
  end

  if action.command then
    local cmd = type(action.command) == "table" and action.command.command or tostring(action.command)
    append_kv(lines, spans, "Command:   ", cmd or "unknown")
  end

  if action.data ~= nil then
    append_kv(lines, spans, "Resolve:   ", "lazy (data available)")
  end

  if action.edit then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Workspace Edit"
    spans[#spans + 1] = { row = #lines - 1, file = true }
    local el, es = summarize_workspace_edit(action.edit)
    local base = #lines
    vim.list_extend(lines, el)
    for _, s in ipairs(es) do
      spans[#spans + 1] = { row = base + s.row, file = s.file }
    end
  elseif not action.command then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "No edit or command payload (lazy resolution)."
  end

  return lines, spans
end

-- ── Diff computation ──────────────────────────────────────────────────────────

-- Returns structured preview content or nil.
-- We compute the diff ourselves and apply extmark highlights, which is more
-- reliable than setting 'diff' option on two windows.
---@param action table
---@param client vim.lsp.Client|nil
---@return { lines: string[], hl: table[], signs: table[], filetype?: string, lang?: string }|nil
local function compute_diff(action, client)
  if not action or not action.edit then
    return nil
  end

  local encoding = client and client.offset_encoding or "utf-8"
  local result = { lines = {}, hl = {}, signs = {}, filetypes = {} }
  local max_lines = vim.g.lsp_diff_max_lines or 1000

  local function add_line(text, hl_group, sign, sign_hl)
    local lnum = #result.lines
    result.lines[#result.lines + 1] = text
    if hl_group then
      result.hl[#result.hl + 1] = { lnum = lnum, hl_group = hl_group }
    end
    if sign then
      result.signs[#result.signs + 1] = {
        lnum = lnum,
        text = sign,
        hl_group = sign_hl or hl_group or HL.PreviewSign,
      }
    end
    return lnum
  end

  local function add_meta(text, hl_group)
    local lnum = add_line(text, hl_group or HL.PreviewMeta, " ", HL.PreviewMeta)
    result.hl[#result.hl + 1] = { lnum = lnum, hl_group = hl_group or HL.PreviewMeta, meta = true }
  end

  local function parse_hunk_start(line)
    local old_start, new_start = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    return tonumber(old_start), tonumber(new_start)
  end

  local function diff_uri(uri, text_edits)
    local fname = vim.uri_to_fname(uri)
    local rel = vim.fn.fnamemodify(fname, ":~:.")

    local orig = {}
    local ebuf = vim.fn.bufnr(fname)
    if ebuf ~= -1 and vim.api.nvim_buf_is_loaded(ebuf) then
      orig = vim.api.nvim_buf_get_lines(ebuf, 0, -1, false)
    else
      local ok, file_lines = pcall(vim.fn.readfile, fname)
      if ok then
        orig = file_lines
      end
    end

    -- Apply edits onto a scratch buffer.
    local scratch = require("custom.ui.buffer").create_raw(false, true)
    local ok = pcall(function()
      vim.api.nvim_buf_set_lines(scratch, 0, -1, false, orig)
      vim.lsp.util.apply_text_edits(text_edits, scratch, encoding)
    end)
    local modified = ok and vim.api.nvim_buf_get_lines(scratch, 0, -1, false) or orig
    vim.api.nvim_buf_delete(scratch, { force = true })

    local ft = detect_filetype(fname, modified)
    result.filetypes[ft] = true

    local a_text = table.concat(orig, "\n") .. "\n"
    local b_text = table.concat(modified, "\n") .. "\n"
    if a_text == b_text then
      return
    end

    local diff_str = vim.text.diff(a_text, b_text, {
      result_type = "unified",
      algorithm = "minimal",
      ctxlen = 3,
    })
    if not diff_str or diff_str == "" then
      return
    end

    local diff_lines = vim.split(tostring(diff_str), "\n", { plain = true })
    -- Remove trailing empty line that split may produce.
    while #diff_lines > 0 and diff_lines[#diff_lines] == "" do
      diff_lines[#diff_lines] = nil
    end

    local base = #result.lines
    if base > 0 then
      add_meta("")
    end
    add_meta(("File: %s"):format(rel), HL.Header)
    add_meta(("Type: %s"):format(ft), HL.PreviewMeta)

    local truncated = false
    local old_lnum, new_lnum = 0, 0
    local pending_removed = 0
    for _, dl in ipairs(diff_lines) do
      if #result.lines - base > max_lines then
        add_meta("... diff truncated")
        truncated = true
        break
      end

      if dl:match("^%+%+%+") or dl:match("^%-%-%-") then
        -- Skip synthetic unified-diff file headers; the preview has its own.
      elseif dl:match("^@@") then
        pending_removed = 0
        local old_start, new_start = parse_hunk_start(dl)
        old_lnum = (old_start or 1) - 1
        new_lnum = (new_start or 1) - 1
        add_meta(dl, HL.DiffHunk)
      elseif dl:match("^%+") then
        new_lnum = new_lnum + 1
        if pending_removed > 0 then
          pending_removed = pending_removed - 1
          add_line(dl:sub(2), HL.DiffChange, "~", HL.DiffChange)
        else
          add_line(dl:sub(2), HL.DiffAdd, "+", HL.DiffAdd)
        end
      elseif dl:match("^%-") then
        old_lnum = old_lnum + 1
        pending_removed = pending_removed + 1
        add_line(dl:sub(2), HL.DiffDelete, "-", HL.DiffDelete)
      elseif dl:match("^ ") then
        pending_removed = 0
        old_lnum = old_lnum + 1
        new_lnum = new_lnum + 1
        add_line(dl:sub(2), nil, " ", HL.PreviewSign)
      elseif dl ~= "" then
        pending_removed = 0
        add_meta(dl)
      end
      _ = truncated
      _ = old_lnum
      _ = new_lnum
    end
  end

  if action.edit.documentChanges then
    for _, change in ipairs(action.edit.documentChanges) do
      if change.kind == "rename" then
        add_meta(("Rename: %s -> %s"):format(
          vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":~:."),
          vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":~:.")
        ), HL.Header)
      elseif change.kind == "delete" then
        add_meta(("Delete: %s"):format(
          vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")
        ), HL.DiffDelete)
      elseif change.kind == "create" then
        add_meta(("Create: %s"):format(
          vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":~:.")
        ), HL.DiffAdd)
      elseif change.textDocument and change.edits then
        diff_uri(change.textDocument.uri, change.edits)
      end
    end
  elseif action.edit.changes then
    local uris = vim.tbl_keys(action.edit.changes)
    table.sort(uris)
    for _, uri in ipairs(uris) do
      diff_uri(uri, action.edit.changes[uri])
    end
  end

  local filetypes = vim.tbl_keys(result.filetypes)
  table.sort(filetypes)
  if #filetypes == 1 then
    result.filetype = filetypes[1]
    result.lang = treesitter_lang_for_filetype(result.filetype)
  elseif #filetypes > 1 then
    result.filetype = "diff"
  end
  result.filetypes = nil

  return (#result.lines > 0) and result or nil
end

-- ── Float helpers ─────────────────────────────────────────────────────────────

---Apply standard window-local options to a float window.
---Uses the scoped vim.wo API available since Neovim 0.11.
---@param win integer
---@param opts { cursorline?: boolean, wrap?: boolean, winblend?: integer }
local function configure_float(win, opts)
  local wo = vim.wo[win]
  wo.cursorline = opts.cursorline or false
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = opts.signcolumn or "no"
  wo.wrap = opts.wrap or false
  wo.scrolloff = 0
  wo.winblend = opts.winblend or 0
  wo.winhighlight = table.concat({
    "Normal:" .. HL.Normal,
    "FloatBorder:" .. HL.Border,
    "FloatTitle:" .. HL.Title,
    "FloatFooter:" .. HL.Footer,
    "CursorLine:" .. HL.CursorLine,
  }, ",")
  -- Disable folds in preview/picker; 'foldenable' is global-local.
  wo.foldenable = false
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
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

function M.reset()
  is_open = false
end

-- ── Main open function ────────────────────────────────────────────────────────

---@param items        { action: lsp.CodeAction, client: vim.lsp.Client }[]
---@param source_win   integer
---@param source_buf   integer
---@param source_cursor integer[]
---@param opts         { open_preview?: boolean, config?: CodeActionConfig }
function M.open(items, source_win, source_buf, source_cursor, opts)
  opts = opts or {}
  local cfg = opts.config or {}
  local cfg_picker = cfg.picker or {}
  local cfg_preview = cfg.preview or {}
  local km = cfg.keymaps or {}

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

  ---@type { buf: integer|nil, win: integer|nil, open: boolean }
  local preview = { buf = nil, win = nil, open = false }
  local preview_mode = cfg_preview.show_diff and "diff" or "summary"
  local preview_render_key = nil
  local preview_request = 0
  local preview_timer = nil
  local closed = false

  local filter_win = nil
  local filter_buf_ref = nil

  -- ── Geometry ───────────────────────────────────────────────────────────────

  local picker_width = estimate_width(all_items, cfg_picker)
  local picker_height = clamp(#all_rows, 6, math.max(6, math.floor(vim.o.lines * (cfg_picker.max_height_pct or 0.45))))
  local preview_width = clamp(
    math.floor(vim.o.columns * (cfg_preview.width_pct or 0.36)),
    cfg_preview.min_width or 38,
    cfg_preview.max_width or 72
  )
  local picker_row, picker_col = place_picker(picker_width, picker_height, source_win, source_cursor)

  -- ── Picker buffer + window ────────────────────────────────────────────────

  local picker_buf = require("custom.ui.buffer").create_raw(false, true)
  vim.bo[picker_buf].bufhidden = "wipe"
  vim.bo[picker_buf].buftype = "nofile"
  vim.bo[picker_buf].swapfile = false
  vim.bo[picker_buf].filetype = "codeactionmenu"
  -- Prevent accidental modification.
  vim.bo[picker_buf].modifiable = false

  local picker_win = require("custom.ui.window").open_raw(picker_buf, true, {
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
        return title:find(q, 1, true) ~= nil or kind:find(q, 1, true) ~= nil or source:find(q, 1, true) ~= nil
      end, all_items)
      rows, row_item_pos, filtered_count = build_rows(filtered)
    end
  end

  -- ── Close helpers ─────────────────────────────────────────────────────────

  local function restore_focus()
    if vim.api.nvim_win_is_valid(source_win) then
      vim.api.nvim_set_current_win(source_win)
      if vim.api.nvim_buf_is_valid(source_buf) then
        local lc = vim.api.nvim_buf_line_count(source_buf)
        local ln = clamp(source_cursor[1], 1, math.max(lc, 1))
        local row_text = vim.api.nvim_buf_get_lines(source_buf, ln - 1, ln, false)[1] or ""
        local col = clamp(source_cursor[2], 0, math.max(#row_text - 1, 0))
        pcall(vim.api.nvim_win_set_cursor, source_win, { ln, col })
      end
    end
  end

  local stop_preview_treesitter

  local function close_preview()
    preview.open = false
    preview_request = preview_request + 1
    preview_render_key = nil
    if preview_timer then
      preview_timer:stop()
      if not preview_timer:is_closing() then
        preview_timer:close()
      end
      preview_timer = nil
    end
    if preview.buf and vim.api.nvim_buf_is_valid(preview.buf) then
      stop_preview_treesitter(preview.buf)
    end
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
      lines[1] = "  No actions match the filter."
      vim.bo[picker_buf].modifiable = true
      vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
      vim.bo[picker_buf].modifiable = false
      require("custom.ui.render").set_extmark(picker_buf, NS, 0, 0, {
        end_line = 1,
        hl_group = HL.Disabled,
        hl_mode = "replace",
      })
      return
    end

    for _, row in ipairs(rows) do
      if row.kind == "header" then
        lines[#lines + 1] = " " .. row.label
      else
        lines[#lines + 1] = (" %s %s"):format(kinds.get(row.item.action.kind), clean_title(row.item.action))
      end
    end

    vim.bo[picker_buf].modifiable = true
    vim.api.nvim_buf_set_lines(picker_buf, 0, -1, false, lines)
    vim.bo[picker_buf].modifiable = false

    for idx, row in ipairs(rows) do
      local rownr = idx - 1
      if row.kind == "header" then
        local ll = #(vim.api.nvim_buf_get_lines(picker_buf, rownr, rownr + 1, false)[1] or "")
        require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 0, {
          end_col = ll,
          hl_group = HL.Header,
          hl_eol = true,
        })
        require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 0, {
          virt_text = { { ("(%d)"):format(row.count), HL.HeaderCount } },
          virt_text_pos = "right_align",
        })
      else
        local icon = kinds.get(row.item.action.kind)
        require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 1, {
          end_col = 1 + #icon,
          hl_group = HL.Kind,
        })
        if row.item.action.isPreferred then
          require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 0, {
            sign_text = "★",
            sign_hl_group = HL.Preferred,
          })
        end
        if row.item.action.disabled then
          require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 0, {
            hl_group = HL.Disabled,
            hl_eol = true,
          })
        end
        if filter_query ~= "" then
          local q = filter_query:lower()
          local title = clean_title(row.item.action):lower()
          local ms, me = title:find(q, 1, true)
          if ms then
            local prefix = 1 + #icon + 1
            require("custom.ui.render").set_extmark(picker_buf, NS, rownr, prefix + ms - 1, {
              end_col = prefix + me,
              hl_group = HL.FilterMatch,
            })
          end
        end
        local badges = right_badges(row.item)
        if #badges > 0 then
          local virt = {}
          for _, badge in ipairs(badges) do
            virt[#virt + 1] = { badge[1] .. " ", badge[2] }
          end
          require("custom.ui.render").set_extmark(picker_buf, NS, rownr, 0, {
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
    local ftag = filter_query ~= "" and ("  [/%s %d/%d]"):format(filter_query, filtered_count, all_item_count) or ""
    local mtag = preview.open and (" [%s]"):format(preview_mode) or ""
    set_statusline(
      picker_win,
      ("%s  %d/%d%s%s"):format(item.client and item.client.name or "LSP", pos, filtered_count, ftag, mtag)
    )
  end

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
  -- Buffer-picker style (tiny-code-action influence):
  --   • Preview window shows a scratch buffer with the actual diff content.
  --   • Diff highlights are applied via extmarks (no 'diff' option weirdness).
  --   • Summary mode shows structured metadata.
  --   • The preview buffer is reused across item changes.

  local function ensure_preview()
    if preview.open and preview.win and vim.api.nvim_win_is_valid(preview.win) then
      return
    end

    preview.buf = require("custom.ui.buffer").create_raw(false, true)
    vim.bo[preview.buf].bufhidden = "wipe"
    vim.bo[preview.buf].buftype = "nofile"
    vim.bo[preview.buf].swapfile = false
    vim.bo[preview.buf].modifiable = false

    local row, col = place_preview(picker_row, picker_col, picker_width, picker_height, preview_width)
    preview.win = require("custom.ui.window").open_raw(preview.buf, false, {
      relative = "editor",
      row = row,
      col = col,
      width = preview_width,
      height = picker_height,
      style = "minimal",
      border = "rounded",
      title = " Preview ",
      title_pos = "left",
      footer = " K toggle  d diff/summary ",
      footer_pos = "center",
      zindex = 59,
      noautocmd = true,
    })
    configure_float(preview.win, { wrap = true, winblend = cfg_preview.winblend or 0, signcolumn = "yes:1" })
    preview.open = true
  end

  function stop_preview_treesitter(bufnr)
    if type(vim.treesitter) == "table" and type(vim.treesitter.stop) == "function" then
      pcall(vim.treesitter.stop, bufnr)
    end
  end

  local function apply_preview_language(bufnr, filetype, lang)
    stop_preview_treesitter(bufnr)
    vim.bo[bufnr].syntax = "manual"
    vim.bo[bufnr].filetype = filetype or "codeactionpreview"

    if filetype and filetype ~= "diff" and lang and has_treesitter_parser(bufnr, lang) then
      pcall(vim.treesitter.start, bufnr, lang)
      vim.bo[bufnr].syntax = "off"
    elseif filetype == "diff" then
      vim.bo[bufnr].syntax = "diff"
    end
  end

  ---Write content into the preview buffer and apply extmark highlights.
  ---@param lines   string[]
  ---@param hl_list { lnum: integer, hl_group: string }[]|nil
  ---@param signs   { lnum: integer, text: string, hl_group: string }[]|nil
  ---@param spans   table[]|nil   summary-mode label/value spans
  ---@param status  string
  ---@param lang_opts { filetype?: string, lang?: string }|nil
  local function render_preview_content(lines, hl_list, signs, spans, status, lang_opts)
    local pbuf = preview.buf
    if not preview.open or not pbuf or not vim.api.nvim_buf_is_valid(pbuf) then
      return
    end

    vim.bo[pbuf].modifiable = true
    vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, lines)
    vim.bo[pbuf].modifiable = false
    vim.api.nvim_buf_clear_namespace(pbuf, NS, 0, -1)
    apply_preview_language(pbuf, lang_opts and lang_opts.filetype or "codeactionpreview", lang_opts and lang_opts.lang or nil)

    -- Diff extmark highlights (add/remove/hunk header lines).
    for _, h in ipairs(hl_list or {}) do
      require("custom.ui.render").set_extmark(pbuf, NS, h.lnum, 0, {
        hl_group = h.hl_group,
        hl_eol = true,
      })
    end

    for _, sign in ipairs(signs or {}) do
      require("custom.ui.render").set_extmark(pbuf, NS, sign.lnum, 0, {
        sign_text = sign.text,
        sign_hl_group = sign.hl_group,
        virt_text = { { sign.text .. " ", sign.hl_group } },
        virt_text_pos = "inline",
        priority = 120,
      })
    end

    -- Summary-mode key/value and section highlights.
    for _, span in ipairs(spans or {}) do
      if span.file then
        require("custom.ui.render").set_extmark(pbuf, NS, span.row, 0, {
          hl_group = HL.Header,
          hl_eol = true,
        })
      elseif span.label_end then
        require("custom.ui.render").set_extmark(pbuf, NS, span.row, 0, {
          end_col = span.label_end,
          hl_group = HL.PreviewLabel,
        })
        require("custom.ui.render").set_extmark(pbuf, NS, span.row, span.value_start, {
          hl_group = HL.PreviewValue,
          hl_eol = true,
        })
      end
    end

    if preview.win and vim.api.nvim_win_is_valid(preview.win) then
      set_statusline(preview.win, status)
    end
  end

  local function selected_preview_key(item)
    local title = item and item.action and item.action.title or ""
    local client_id = item and item.client and item.client.id or "none"
    return ("%s:%s:%s"):format(preview_mode, client_id, title)
  end

  local function update_preview_now(force)
    if not preview.open and not force then
      return
    end
    local item = current_item()
    if not item then
      return
    end

    ensure_preview()
    local render_key = selected_preview_key(item)
    if preview_render_key == render_key and not force then
      return
    end
    preview_render_key = render_key
    preview_request = preview_request + 1
    local request_id = preview_request
    render_preview_content({ "Loading..." }, {}, {}, {}, " Preview ", { filetype = "codeactionpreview" })

    lsp.resolve_for_preview(item, function(err, action)
      if closed or not preview.open or request_id ~= preview_request then
        return
      end
      if err or not action then
        render_preview_content({ err or "Failed to resolve action" }, {}, {}, {}, " Preview Error ", {
          filetype = "codeactionpreview",
        })
        return
      end

      if preview_mode == "diff" then
        local diff = compute_diff(action, item.client)
        if diff then
          render_preview_content(diff.lines, diff.hl, diff.signs, {}, " Diff  (d: summary) ", {
            filetype = diff.filetype or "diff",
            lang = diff.lang,
          })
        else
          render_preview_content({
            "",
            "No diff available for this action.",
            "",
            "Possible reasons:",
            "- Action uses lazy resolution (no edit yet)",
            "- Command-only action",
            "- File create / rename / delete",
          }, {}, {}, {}, " Diff  (d: summary) ", { filetype = "markdown" })
        end
      else
        local lines, spans = summary_preview_lines(action, item)
        render_preview_content(lines, {}, {}, spans, " Summary  (d: diff) ", { filetype = "codeactionpreview" })
      end
    end)
  end

  local function update_preview(force)
    if preview_timer then
      preview_timer:stop()
      if not preview_timer:is_closing() then
        preview_timer:close()
      end
      preview_timer = nil
    end
    if force then
      update_preview_now(true)
      return
    end
    preview_timer = vim.defer_fn(function()
      preview_timer = nil
      update_preview_now(false)
    end, cfg_preview.debounce_ms or 35)
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
    if filter_win and vim.api.nvim_win_is_valid(filter_win) then
      vim.api.nvim_set_current_win(filter_win)
      vim.cmd("startinsert!")
      return
    end

    filter_buf_ref = require("custom.ui.buffer").create_raw(false, true)
    vim.bo[filter_buf_ref].bufhidden = "wipe"
    vim.bo[filter_buf_ref].buftype = "nofile"

    if filter_query ~= "" then
      vim.api.nvim_buf_set_lines(filter_buf_ref, 0, -1, false, { filter_query })
    end

    local f_row = picker_row + picker_height + 2
    if f_row + 3 > vim.o.lines then
      f_row = math.max(0, picker_row - 3)
    end

    filter_win = require("custom.ui.window").open_raw(filter_buf_ref, true, {
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
      if vim.api.nvim_win_is_valid(picker_win) then
        vim.api.nvim_set_current_win(picker_win)
      end
      apply_filter(query)
      render_picker()
      if #rows > 0 then
        vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
      end
      update_picker_status()
      if preview.open then
        update_preview(false)
      end
    end

    local function cancel_filter()
      vim.cmd("stopinsert")
      if filter_win and vim.api.nvim_win_is_valid(filter_win) then
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

  local function map_all(keys_or_key, rhs)
    local keys = type(keys_or_key) == "table" and keys_or_key or { keys_or_key }
    for _, k in ipairs(keys) do
      map(k, rhs)
    end
  end

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

  for n = 1, 9 do
    map(tostring(n), function()
      go_to_item(n)
    end)
  end

  map("<2-LeftMouse>", execute_selected)
  map("<ScrollWheelDown>", function()
    nav(3)
  end)
  map("<ScrollWheelUp>", function()
    nav(-3)
  end)

  -- ── Autocmds ──────────────────────────────────────────────────────────────

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = picker_buf,
    callback = function()
      if closed then
        return
      end
      if #rows == 0 then
        return
      end
      local row = current_row_index()
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

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(source_win),
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = picker_buf,
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  -- Resize preview when the editor is resized.
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if closed then
        return
      end
      if preview.open and preview.win and vim.api.nvim_win_is_valid(preview.win) then
        local new_pw = clamp(
          math.floor(vim.o.columns * (cfg_preview.width_pct or 0.36)),
          cfg_preview.min_width or 38,
          cfg_preview.max_width or 72
        )
        local pr, pc = place_preview(picker_row, picker_col, picker_width, picker_height, new_pw)
        vim.api.nvim_win_set_config(preview.win, {
          relative = "editor",
          row = pr,
          col = pc,
          width = new_pw,
          height = picker_height,
        })
      end
    end,
  })

  -- ── Auto-open preview ─────────────────────────────────────────────────────

  if opts.open_preview then
    update_preview(true)
  end
end

return M
