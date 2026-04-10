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

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

local function dw(s)
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

local function estimate_width(items)
  local max_width = 0
  for _, item in ipairs(items) do
    local right = 0
    for _, badge in ipairs(right_badges(item)) do
      right = right + dw(badge[1]) + 1
    end
    max_width = math.max(max_width, 4 + kinds.symbol_width() + dw(clean_title(item.action)) + right + 6)
  end
  for _, group in ipairs(GROUPS) do
    max_width = math.max(max_width, dw(group.label) + 8)
  end
  return clamp(max_width, 48, math.max(48, math.floor(vim.o.columns * 0.50)))
end

local function build_rows(items)
  local grouped = {
    quickfix = {},
    refactor = {},
    source = {},
    other = {},
  }

  for _, item in ipairs(items) do
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
  for _, group in ipairs(GROUPS) do
    local bucket = grouped[group.key]
    if #bucket > 0 then
      table.insert(rows, {
        kind = "header",
        label = group.label,
        count = #bucket,
      })
      for _, item in ipairs(bucket) do
        table.insert(rows, {
          kind = "item",
          item = item,
        })
      end
    end
  end

  return rows
end

local function first_item_row(rows)
  for index, row in ipairs(rows) do
    if row.kind == "item" then
      return index
    end
  end
  return 1
end

local function next_item_row(rows, start, delta)
  local index = start
  repeat
    index = clamp(index + delta, 1, #rows)
    if rows[index].kind == "item" then
      return index
    end
  until index == 1 or index == #rows
  return start
end

local function range_label(range)
  if not range then
    return "?"
  end
  local s = range.start or range["start"]
  local e = range["end"]
  return string.format("L%d:%d-L%d:%d", s.line + 1, s.character + 1, e.line + 1, e.character + 1)
end

local function text_preview(text)
  local normalized = tostring(text or ""):gsub("\r", ""):gsub("\n", "\\n")
  if normalized == "" then
    return '""'
  end
  if #normalized > 90 then
    normalized = normalized:sub(1, 87) .. "..."
  end
  return normalized
end

local function append_kv(lines, spans, label, value)
  table.insert(lines, label .. value)
  table.insert(spans, { row = #lines - 1, label_end = #label, value_start = #label })
end

local function summarize_workspace_edit(edit)
  local lines = {}
  local spans = {}

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

local function preview_lines(action, item)
  local lines = {}
  local spans = {}

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

local function configure_float(win, opts)
  vim.wo[win].cursorline = opts.cursorline or false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = opts.wrap or false
  vim.wo[win].scrolloff = 0
  vim.wo[win].winblend = 0
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

function M.open(items, source_win, source_buf, source_cursor, opts)
  opts = opts or {}

  if is_open then
    vim.notify("Code action menu is already open", vim.log.levels.WARN, { title = "Code Actions" })
    return
  end

  if vim.tbl_isempty(items) then
    vim.notify("No code actions available", vim.log.levels.INFO, { title = "Code Actions" })
    return
  end

  is_open = true

  local rows = build_rows(items)
  local picker_width = estimate_width(items)
  local picker_height = clamp(#rows, 6, math.max(6, math.floor(vim.o.lines * 0.45)))
  local preview_width = clamp(math.floor(vim.o.columns * 0.36), 38, 72)
  local picker_row, picker_col = place_picker(picker_width, picker_height, source_win, source_cursor)

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
    footer = " <CR> apply  K preview  q close ",
    footer_pos = "center",
    zindex = 60,
    noautocmd = true,
  })

  configure_float(picker_win, { cursorline = true })

  local preview = { buf = nil, win = nil, open = false }
  local closed = false

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
    if preview.win and vim.api.nvim_win_is_valid(preview.win) then
      pcall(vim.api.nvim_win_close, preview.win, true)
    end
    if preview.buf and vim.api.nvim_buf_is_valid(preview.buf) then
      pcall(vim.api.nvim_buf_delete, preview.buf, { force = true })
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
    close_preview()
    if vim.api.nvim_win_is_valid(picker_win) then
      pcall(vim.api.nvim_win_close, picker_win, true)
    end
    restore_focus()
  end

  local function render_picker()
    vim.api.nvim_buf_clear_namespace(picker_buf, NS, 0, -1)
    local lines = {}

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
        vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Kind, rownr, 1, 1 + #icon)
        if row.item.action.disabled then
          vim.api.nvim_buf_add_highlight(picker_buf, NS, HL.Disabled, rownr, 0, -1)
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

  local function current_row_index()
    if not vim.api.nvim_win_is_valid(picker_win) then
      return first_item_row(rows)
    end
    local index = vim.api.nvim_win_get_cursor(picker_win)[1]
    if rows[index].kind == "header" then
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
    local item, index = current_item()
    if not item then
      return
    end
    local pos = 0
    for i = 1, index do
      if rows[i].kind == "item" then
        pos = pos + 1
      end
    end
    set_statusline(picker_win, string.format("%s  %d/%d", item.client and item.client.name or "LSP", pos, #items))
  end

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
      footer = " K toggle  <CR> apply ",
      footer_pos = "center",
      zindex = 59,
      noautocmd = true,
    })
    configure_float(preview.win, { wrap = true })
    preview.open = true
  end

  local function render_preview_message(lines, spans, status)
    if not preview.open then
      return
    end

    vim.bo[preview.buf].modifiable = true
    vim.api.nvim_buf_set_lines(preview.buf, 0, -1, false, lines)
    vim.bo[preview.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(preview.buf, NS, 0, -1)

    for _, span in ipairs(spans or {}) do
      if span.file then
        vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.Header, span.row, 0, -1)
      elseif span.label_end then
        vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.PreviewLabel, span.row, 0, span.label_end)
        vim.api.nvim_buf_add_highlight(preview.buf, NS, HL.PreviewValue, span.row, span.value_start, -1)
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
    render_preview_message({ "Loading preview..." }, {}, " Preview ")
    lsp.resolve_for_preview(item, function(err, action)
      if closed or not preview.open then
        return
      end
      if err then
        render_preview_message({ err }, {}, " Preview Error ")
        return
      end
      local lines, spans = preview_lines(action, item)
      render_preview_message(lines, spans, " Preview ")
    end)
  end

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

  render_picker()
  vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
  update_picker_status()

  local map_opts = { buffer = picker_buf, silent = true, nowait = true }
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, map_opts)
  end

  map("<CR>", execute_selected)
  map("<Esc>", close)
  map("q", close)
  map("j", function()
    nav(1)
  end)
  map("k", function()
    nav(-1)
  end)
  map("<Down>", function()
    nav(1)
  end)
  map("<Up>", function()
    nav(-1)
  end)
  map("<C-n>", function()
    nav(1)
  end)
  map("<C-p>", function()
    nav(-1)
  end)
  map("gg", function()
    vim.api.nvim_win_set_cursor(picker_win, { first_item_row(rows), 0 })
    update_picker_status()
    if preview.open then
      update_preview(false)
    end
  end)
  map("G", function()
    local row = next_item_row(rows, #rows, -1)
    vim.api.nvim_win_set_cursor(picker_win, { row, 0 })
    update_picker_status()
    if preview.open then
      update_preview(false)
    end
  end)
  map("<C-d>", function()
    nav(math.max(1, math.floor(picker_height / 2)))
  end)
  map("<C-u>", function()
    nav(-math.max(1, math.floor(picker_height / 2)))
  end)
  map("K", function()
    if preview.open then
      close_preview()
      update_picker_status()
      return
    end
    update_preview(true)
  end)
  map("p", function()
    if preview.open then
      close_preview()
      update_picker_status()
      return
    end
    update_preview(true)
  end)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = picker_buf,
    callback = function()
      if closed then
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

  if opts.open_preview then
    update_preview(true)
  end
end

return M
