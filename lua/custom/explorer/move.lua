local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")

local api = vim.api
local fn = vim.fn

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────

local NS = api.nvim_create_namespace("explorer_move_picker")
local INPUT_PREFIX = "    "
local INPUT_PREFIX_LEN = #INPUT_PREFIX
local HEADER_SIZE = 4 -- 3 lines for border/input + 1 line for target path

-- ── Picker state ──────────────────────────────────────────────────────────

local P = {
  buf = nil,
  win = nil,
  filter = "",
  cursor_idx = 1, -- 1-based index into P.filtered (0 is "..")
  current_dir = nil,
  on_confirm = nil,
  entries = {},
  filtered = {},
  active_mode = "normal", -- "normal" or "insert"
}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function relative_to_root(path)
  if not path or path == "" then
    return ""
  end
  if path == S.root then
    return "."
  end
  local prefix = S.root .. "/"
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end
  return fn.fnamemodify(path, ":~")
end

local function scan_dirs(root)
  local handle = vim.uv.fs_scandir(root)
  if not handle then
    return {}
  end
  local out = {}
  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local is_dir = entry_type == "directory"
    local is_link = entry_type == "link"
    local path = tree.join(root, name)
    if is_link then
      local stat = vim.uv.fs_stat(path)
      if stat then
        is_dir = stat.type == "directory"
      end
    end
    if cfg.get().show_hidden or name:sub(1, 1) ~= "." then
      out[#out + 1] = { name = name, path = path, is_dir = is_dir, is_link = is_link }
    end
  end
  table.sort(out, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir
    end
    return a.name:lower() < b.name:lower()
  end)
  return out
end

local function apply_filter()
  local q = vim.trim(P.filter:lower())
  P.filtered = {}
  for _, e in ipairs(P.entries) do
    if q == "" or e.name:lower():find(q, 1, true) or e.path:lower():find(q, 1, true) then
      P.filtered[#P.filtered + 1] = e
    end
  end
end

-- ── close ─────────────────────────────────────────────────────────────────

local function close(skip_restore)
  local explorer_win = S.win
  if P.win and api.nvim_win_is_valid(P.win) then
    pcall(api.nvim_win_close, P.win, true)
  end
  if P.buf and api.nvim_buf_is_valid(P.buf) then
    pcall(api.nvim_buf_delete, P.buf, { force = true })
  end

  P.buf = nil
  P.win = nil
  P.filter = ""
  P.cursor_idx = 1
  P.current_dir = nil
  P.on_confirm = nil
  P.entries = {}
  P.filtered = {}
  P.active_mode = "normal"

  if not skip_restore then
    vim.schedule(function()
      if fn.mode():sub(1, 1) == "i" then
        vim.cmd("stopinsert")
      end
      if explorer_win and api.nvim_win_is_valid(explorer_win) then
        api.nvim_set_current_win(explorer_win)
      end
    end)
  end
end

-- ── Rendering ─────────────────────────────────────────────────────────────

local function paint_header()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end
  local width = api.nvim_win_get_width(P.win)
  local inner = width - 2
  local title = " MOVE "
  local left = math.floor((inner - #title) / 2)
  local right = inner - #title - left
  local top_border = "╭" .. ("─"):rep(left) .. title .. ("─"):rep(right) .. "╮"
  local mid_border = "├" .. ("─"):rep(inner) .. "┤"

  local target_line = "│ 󰉋 Target: " .. relative_to_root(P.current_dir)
  target_line = target_line .. (" "):rep(width - fn.strdisplaywidth(target_line) - 1) .. "│"

  local input_line = "│" .. INPUT_PREFIX .. P.filter
  input_line = input_line .. (" "):rep(width - fn.strdisplaywidth(input_line) - 1) .. "│"

  api.nvim_buf_set_lines(P.buf, 0, HEADER_SIZE, false, {
    top_border,
    target_line,
    input_line,
    mid_border,
  })

  api.nvim_buf_clear_namespace(P.buf, NS, 0, HEADER_SIZE)

  -- Borders
  local border_hl = P.active_mode == "insert" and "ExplorerSearchBorderActive" or "ExplorerSearchBorder"
  for i = 0, 3 do
    pcall(require("custom.ui.render").set_extmark, P.buf, NS, i, 0, {
      end_col = -1,
      hl_group = border_hl,
      hl_eol = true,
      priority = 5,
    })
  end

  -- Title
  pcall(require("custom.ui.render").set_extmark, P.buf, NS, 0, left + 1, {
    end_col = left + 1 + #title,
    hl_group = "ExplorerSearchTitle",
    priority = 20,
  })

  -- Target line highlights
  pcall(require("custom.ui.render").set_extmark, P.buf, NS, 1, 2, {
    end_col = 5,
    hl_group = "ExplorerSearchIcon",
    priority = 20,
  })
  pcall(require("custom.ui.render").set_extmark, P.buf, NS, 1, 6, {
    end_col = 13,
    hl_group = "ExplorerPopupPrompt",
    priority = 15,
  })

  -- Input line highlights
  local input_bg = P.active_mode == "insert" and "ExplorerSearchBgActive" or "ExplorerSearchBg"
  local icon_hl = P.active_mode == "insert" and "ExplorerSearchIconActive" or "ExplorerSearchIcon"

  pcall(require("custom.ui.render").set_extmark, P.buf, NS, 2, 1, {
    end_col = width - 1,
    hl_group = input_bg,
    priority = 5,
  })
  pcall(require("custom.ui.render").set_extmark, P.buf, NS, 2, 3, {
    end_col = 6,
    hl_group = icon_hl,
    priority = 20,
  })

  if P.filter == "" and P.active_mode ~= "insert" then
    pcall(require("custom.ui.render").set_extmark, P.buf, NS, 2, INPUT_PREFIX_LEN + 1, {
      virt_text = { { "filter folders…", "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 15,
    })
  end
end

local function paint_items()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end

  local lines = { "  .. " }
  local marks = {
    { row = 0, col = 2, vt = { { "󰉋 ", "ExplorerDirectory" } }, pri = 25 },
  }

  if #P.filtered == 0 then
    if P.filter ~= "" then
      lines[#lines + 1] = "     No results for '" .. P.filter .. "'"
      marks[#marks + 1] = { row = 1, col = 0, hl = "Comment", pri = 10 }
    end
  else
    local icon_fn = S.icon_fn or function()
      return "󰈔", "ExplorerFile"
    end

    for i, entry in ipairs(P.filtered) do
      lines[#lines + 1] = "     " .. entry.name
      local row = i
      local icon, icon_hl = icon_fn(entry.path, entry.is_dir, entry.is_link)
      if not entry.is_dir then
        icon_hl = "Comment" -- Dim files in move picker
      end

      marks[#marks + 1] = { row = row, col = 2, vt = { { icon .. " ", icon_hl } }, pri = 25 }

      if not entry.is_dir then
        marks[#marks + 1] = { row = row, col = 5, hl = "Comment", pri = 10 }
      end

      -- Right-aligned path
      marks[#marks + 1] = {
        row = row,
        col = 0,
        vt = { { " " .. relative_to_root(entry.path), "Comment" } },
        pos = "right_align",
        pri = 10,
      }
    end
  end

  api.nvim_buf_set_lines(P.buf, HEADER_SIZE, -1, false, lines)
  api.nvim_buf_clear_namespace(P.buf, NS, HEADER_SIZE, -1)

  for _, m in ipairs(marks) do
    local row = HEADER_SIZE + m.row
    if m.hl then
      pcall(require("custom.ui.render").set_extmark, P.buf, NS, row, m.col, {
        end_col = -1,
        hl_group = m.hl,
        hl_eol = true,
        priority = m.pri,
      })
    else
      pcall(require("custom.ui.render").set_extmark, P.buf, NS, row, m.col, {
        virt_text = m.vt,
        virt_text_pos = m.pos or "overlay",
        priority = m.pri,
      })
    end
  end
end

local function paint_all()
  paint_header()
  paint_items()
end

-- ── Navigation ────────────────────────────────────────────────────────────

local function refresh_entries()
  P.entries = scan_dirs(P.current_dir)
  apply_filter()
  paint_all()
end

local function sync_cursor()
  if not (P.win and api.nvim_win_is_valid(P.win)) then
    return
  end
  if P.active_mode == "insert" then
    return
  end
  local row = api.nvim_win_get_cursor(P.win)[1]
  local min_row = HEADER_SIZE + 1
  local max_row = HEADER_SIZE + 1 + #P.filtered
  if row < min_row then
    api.nvim_win_set_cursor(P.win, { min_row, 5 })
    row = min_row
  elseif row > max_row then
    api.nvim_win_set_cursor(P.win, { max_row, 5 })
    row = max_row
  end
  P.cursor_idx = row - HEADER_SIZE - 1
end

local function move_to_idx(idx)
  if not (P.win and api.nvim_win_is_valid(P.win)) then
    return
  end
  P.cursor_idx = math.max(0, math.min(#P.filtered, idx))
  api.nvim_win_set_cursor(P.win, { HEADER_SIZE + P.cursor_idx + 1, 5 })
end

local function go_parent()
  if not P.current_dir or P.current_dir == S.root or P.current_dir == "/" then
    return
  end
  P.current_dir = tree.parent(P.current_dir)
  P.filter = ""
  refresh_entries()
  move_to_idx(0)
end

local function enter_dir()
  if P.cursor_idx == 0 then
    go_parent()
    return
  end
  local entry = P.filtered[P.cursor_idx]
  if not entry or not entry.is_dir then
    return
  end
  P.current_dir = entry.path
  P.filter = ""
  refresh_entries()
  move_to_idx(0)
end

local function confirm_move()
  local cb = P.on_confirm
  local target = P.current_dir
  close()
  if cb and target then
    vim.schedule(function()
      cb(target)
    end)
  end
end

local function enter_or_confirm()
  if P.cursor_idx == 0 then
    confirm_move()
    return
  end
  local entry = P.filtered[P.cursor_idx]
  if entry and entry.is_dir then
    enter_dir()
  else
    -- If on a file or nothing, confirm move to current_dir
    confirm_move()
  end
end

-- ── Input Mode ────────────────────────────────────────────────────────────

local function activate_insert()
  P.active_mode = "insert"
  paint_header()
  api.nvim_win_set_cursor(P.win, { 3, INPUT_PREFIX_LEN + #P.filter + 1 })
  vim.cmd("startinsert")
end

local function deactivate_insert()
  P.active_mode = "normal"
  vim.cmd("stopinsert")
  paint_header()
  move_to_idx(P.cursor_idx)
end

-- ── M.open ────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  close(true)
  require("custom.explorer.win").ensure_hl()

  P.current_dir = opts.start_dir or S.root
  P.on_confirm = opts.on_confirm

  local buf = require("custom.ui.buffer").create_raw(false, true)
  P.buf = buf
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "explorer_move"

  local editor_w, editor_h = require("custom.ui.window").editor_size()
  local width = math.min(84, editor_w - 8)
  local height = math.min(24, editor_h - 6)
  local row, col = require("custom.ui.window").center(width, height)

  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none", -- We draw our own borders in the buffer for a cleaner look
  })
  P.win = win

  local wo = vim.wo[win]
  wo.winhl = "Normal:ExplorerNormal,CursorLine:ExplorerCursorLine"
  wo.cursorline = true

  -- ── Autocmds ─────────────────────────────────────────────────────────

  api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = sync_cursor,
  })

  api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      local line = api.nvim_buf_get_lines(buf, 2, 3, false)[1] or ""
      P.filter = line:sub(INPUT_PREFIX_LEN + 1)
      apply_filter()
      paint_items()
    end,
  })

  -- ── Keymaps ──────────────────────────────────────────────────────────

  local bopts = { buffer = buf, silent = true, noremap = true }

  -- Normal mode
  vim.keymap.set("n", "j", "j", bopts)
  vim.keymap.set("n", "k", "k", bopts)
  vim.keymap.set("n", "h", go_parent, bopts)
  vim.keymap.set("n", "l", enter_dir, bopts)
  vim.keymap.set("n", "<Right>", enter_dir, bopts)
  vim.keymap.set("n", "<Left>", go_parent, bopts)
  vim.keymap.set("n", "-", go_parent, bopts)
  vim.keymap.set("n", "i", activate_insert, bopts)
  vim.keymap.set("n", "a", activate_insert, bopts)
  vim.keymap.set("n", "/", activate_insert, bopts)
  vim.keymap.set("n", "y", confirm_move, bopts)
  vim.keymap.set("n", "<CR>", enter_or_confirm, bopts)
  vim.keymap.set("n", "q", close, bopts)
  vim.keymap.set("n", "<Esc>", close, bopts)

  -- Insert mode
  vim.keymap.set("i", "<Esc>", deactivate_insert, bopts)
  vim.keymap.set("i", "<C-c>", deactivate_insert, bopts)
  vim.keymap.set("i", "<CR>", function()
    deactivate_insert()
    enter_or_confirm()
  end, bopts)
  vim.keymap.set("i", "<C-j>", function()
    move_to_idx(P.cursor_idx + 1)
  end, bopts)
  vim.keymap.set("i", "<C-k>", function()
    move_to_idx(P.cursor_idx - 1)
  end, bopts)

  -- Initial render
  refresh_entries()
  move_to_idx(1) -- Start on the first subdirectory
end

return M
