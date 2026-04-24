local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")

local api = vim.api
local fn = vim.fn

local M = {}

-- ── Picker state ──────────────────────────────────────────────────────────

local P = {
  buf = nil,
  win = nil,
  filter = "",
  cursor = 1,
  current_dir = nil,
  on_confirm = nil,
  entries = {},
  filtered = {},
}

local NS = api.nvim_create_namespace("explorer_move_picker")
local ICON_PREFIX = "     " -- 5 spaces matching the search icon overlay width
local SEARCH_ICON = " 󰉋  " -- folder icon overlay (5 display cols)
local PLACEHOLDER = "jump to folder…"

-- ── close ─────────────────────────────────────────────────────────────────
--
-- Safe to call from insert OR normal mode.  Schedules focus restoration so
-- any pending mode transition (insert → normal) settles before we switch
-- windows — this is what prevents the explorer from becoming unresponsive.

local function close()
  local explorer_win = S.win -- capture before state reset

  if P.win and api.nvim_win_is_valid(P.win) then
    pcall(api.nvim_win_close, P.win, true)
  end
  if P.buf and api.nvim_buf_is_valid(P.buf) then
    pcall(api.nvim_buf_delete, P.buf, { force = true })
  end

  P.buf = nil
  P.win = nil
  P.filter = ""
  P.cursor = 1
  P.current_dir = nil
  P.on_confirm = nil
  P.entries = {}
  P.filtered = {}

  -- Scheduled so the event loop can finish any mode transitions before we
  -- switch focus.  Without vim.schedule the explorer can end up in insert
  -- mode (inheriting the picker's insert state) and become unresponsive.
  vim.schedule(function()
    if fn.mode():sub(1, 1) == "i" then
      vim.cmd("stopinsert")
    end
    if explorer_win and api.nvim_win_is_valid(explorer_win) then
      api.nvim_set_current_win(explorer_win)
    end
  end)
end

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

local function current_entry()
  return P.filtered[P.cursor]
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
    if entry_type == "directory" and (cfg.get().show_hidden or name:sub(1, 1) ~= ".") then
      out[#out + 1] = { name = name, path = tree.join(root, name) }
    end
  end
  table.sort(out, function(a, b)
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
  P.cursor = math.max(1, math.min(P.cursor, math.max(1, #P.filtered)))
end

-- ── Pin cursor to row 1 (the search bar) ─────────────────────────────────
--
-- The result highlight is driven purely by P.cursor + extmarks.
-- The real Neovim cursor must stay on row 1 so insert-mode typing works.

local function pin_cursor()
  if P.win and api.nvim_win_is_valid(P.win) then
    pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
  end
end

-- ── paint_header ──────────────────────────────────────────────────────────
--
-- Search-bar row (row 0):
--   • Full-row active background wash
--   • Folder icon overlay
--   • Placeholder when filter is empty
--   • Right-aligned "target: <dir>" badge
--   • Full-width ━━━ separator below (snacks.nvim aesthetic)

local function paint_header()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end
  api.nvim_buf_clear_namespace(P.buf, NS, 0, 1)

  -- 1. Background wash
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    end_col = -1,
    hl_group = "ExplorerSearchBgActive",
    hl_eol = true,
    priority = 5,
  })

  -- 2. Folder icon overlay
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    virt_text = { { SEARCH_ICON, "ExplorerSearchIconActive" } },
    virt_text_pos = "overlay",
    priority = 100,
  })

  -- 3. Placeholder when filter is empty
  if P.filter == "" then
    pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  end

  -- 4. Right-aligned target directory badge
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    virt_text = { { " target: " .. relative_to_root(P.current_dir) .. " ", "ExplorerSearchCountActive" } },
    virt_text_pos = "right_align",
    priority = 70,
  })

  -- 5. Full-width heavy separator (picker is always "active" / insert mode)
  local inner_w = (P.win and api.nvim_win_is_valid(P.win)) and api.nvim_win_get_width(P.win) or 60
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    virt_lines = { { { ("━"):rep(inner_w), "ExplorerSearchBorderActive" } } },
    priority = 100,
  })
end

-- ── paint_items ───────────────────────────────────────────────────────────

local function paint_items()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end

  -- Row 1 always shows ".." as a quick parent shortcut.
  local lines = { "   .." }
  local marks = {
    { kind = "vt", row = 1, col = 3, vt = { { "󰉋 ", "ExplorerDirectory" } }, pos = "overlay", pri = 25 },
  }

  if #P.filtered == 0 then
    local msg = (P.filter ~= "") and ('   No folders match "' .. P.filter .. '".') or "   (no subdirectories)"
    lines[#lines + 1] = msg
    marks[#marks + 1] = { kind = "hl", row = 2, cs = 0, ce = -1, hl = "Comment", eol = true, pri = 10 }
  else
    for idx, entry in ipairs(P.filtered) do
      local row = idx + 1
      lines[#lines + 1] = "     " .. entry.name

      if idx == P.cursor then
        marks[#marks + 1] = { kind = "hl", row = row, cs = 0, ce = -1, hl = "ExplorerCursorLine", eol = true, pri = 10 }
        marks[#marks + 1] =
          { kind = "vt", row = row, col = 0, vt = { { "► ", "ExplorerDirectory" } }, pos = "overlay", pri = 30 }
      end
      marks[#marks + 1] =
        { kind = "vt", row = row, col = 2, vt = { { "󰉋 ", "ExplorerDirectory" } }, pos = "overlay", pri = 25 }
      marks[#marks + 1] = {
        kind = "vt",
        row = row,
        col = 0,
        vt = { { " " .. relative_to_root(entry.path), "Comment" } },
        pos = "right_align",
        pri = 20,
      }
    end
  end

  api.nvim_buf_set_lines(P.buf, 1, -1, false, lines)
  api.nvim_buf_clear_namespace(P.buf, NS, 1, -1)

  for _, m in ipairs(marks) do
    if m.kind == "hl" then
      pcall(api.nvim_buf_set_extmark, P.buf, NS, m.row, m.cs, {
        end_col = m.ce,
        hl_group = m.hl,
        hl_eol = m.eol,
        priority = m.pri,
      })
    else
      pcall(api.nvim_buf_set_extmark, P.buf, NS, m.row, m.col, {
        virt_text = m.vt,
        virt_text_pos = m.pos,
        priority = m.pri,
      })
    end
  end
end

local function paint_all()
  paint_header()
  paint_items()
end

-- ── Navigation actions ────────────────────────────────────────────────────

local function refresh_entries()
  P.entries = scan_dirs(P.current_dir)
  apply_filter()
  paint_all()
  pin_cursor()
end

local function move_cursor(delta)
  if #P.filtered == 0 then
    return
  end
  P.cursor = math.max(1, math.min(#P.filtered, P.cursor + delta))
  paint_items()
  pin_cursor()
end

local function go_parent()
  if not P.current_dir or P.current_dir == "/" then
    return
  end
  P.current_dir = tree.parent(P.current_dir)
  P.filter = ""
  P.cursor = 1
  api.nvim_buf_set_lines(P.buf, 0, 1, false, { ICON_PREFIX })
  refresh_entries()
end

local function enter_dir()
  local entry = current_entry()
  if not entry then
    return
  end
  P.current_dir = entry.path
  P.filter = ""
  P.cursor = 1
  api.nvim_buf_set_lines(P.buf, 0, 1, false, { ICON_PREFIX })
  refresh_entries()
end

-- ── confirm_move / enter_or_confirm ───────────────────────────────────────
--
-- IMPORTANT: confirm_move is forward-declared so enter_or_confirm can
-- reference it as an upvalue.  Without the forward declaration Lua would
-- see an undefined global (nil) at the call site and crash.

local confirm_move -- forward declaration

local function enter_or_confirm()
  if current_entry() then
    enter_dir()
  else
    -- Leaf dir or filter matched nothing → confirm move to current dir.
    confirm_move()
  end
end

confirm_move = function()
  local cb = P.on_confirm
  local target = P.current_dir
  close()
  if cb and target then
    vim.schedule(function()
      cb(target)
    end)
  end
end

-- ── M.open ────────────────────────────────────────────────────────────────

function M.open(opts)
  opts = opts or {}
  close()
  require("custom.explorer.win").ensure_hl()

  P.current_dir = opts.start_dir or S.root
  P.on_confirm = opts.on_confirm

  local buf = api.nvim_create_buf(false, true)
  P.buf = buf

  local bo = vim.bo[buf]
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.buflisted = false
  bo.filetype = "explorer_popup"
  bo.modifiable = true
  bo.swapfile = false
  bo.omnifunc = ""
  bo.completefunc = ""

  -- Suppress all completion engines inside the picker.
  vim.b[buf].completion = false
  vim.b[buf].blink_cmp_enabled = false
  vim.b[buf].cmp_enabled = false
  vim.b[buf].completion_enabled = false

  api.nvim_buf_set_lines(buf, 0, -1, false, { ICON_PREFIX })

  local ui_list = api.nvim_list_uis()
  local editor = ui_list[1]
  local editor_w = editor and editor.width or vim.o.columns
  local editor_h = editor and editor.height or vim.o.lines
  local width = math.min(84, editor_w - 8)
  local height = math.min(24, editor_h - 6)
  local row = math.floor((editor_h - height) / 2)
  local col = math.floor((editor_w - width) / 2)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Move To Folder ",
    title_pos = "center",
    footer = " <CR> confirm/enter   <C-h>/h parent   l enter   y confirm   <Esc> cancel ",
    footer_pos = "center",
  })
  P.win = win

  local wo = vim.wo[win]
  wo.cursorline = false
  wo.wrap = false
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.winhl = table.concat({
    "Normal:ExplorerNormal",
    "FloatBorder:ExplorerPopupBorder",
    "FloatTitle:ExplorerPopupTitle",
    "FloatFooter:ExplorerPopupFooter",
  }, ",")

  -- ── Autocmds ─────────────────────────────────────────────────────────

  -- Keep real cursor on search-bar row in insert mode.
  api.nvim_create_autocmd("CursorMovedI", {
    buffer = buf,
    callback = function()
      if P.win and api.nvim_win_is_valid(P.win) and api.nvim_win_get_cursor(P.win)[1] ~= 1 then
        pin_cursor()
      end
    end,
  })

  -- Same guard in normal mode (e.g. after <C-[> without closing).
  api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if P.win and api.nvim_win_is_valid(P.win) and api.nvim_win_get_cursor(P.win)[1] ~= 1 then
        pin_cursor()
      end
    end,
  })

  -- Live filter: rebuild list on every keystroke.
  api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if not (P.win and api.nvim_win_is_valid(P.win)) then
        return
      end
      local raw = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      if raw:sub(1, #ICON_PREFIX) == ICON_PREFIX then
        P.filter = raw:sub(#ICON_PREFIX + 1)
      else
        -- Prefix corrupted — recover.
        P.filter = ""
        api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
        pin_cursor()
      end
      P.cursor = 1
      apply_filter()
      paint_all()
    end,
  })

  -- ── Keymaps ──────────────────────────────────────────────────────────

  local bopts = { buffer = buf, silent = true, noremap = true }

  -- List-cursor movement (insert + normal).
  vim.keymap.set({ "i", "n" }, "<C-j>", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<C-k>", function()
    move_cursor(-1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<Down>", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<Up>", function()
    move_cursor(-1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<Tab>", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
    move_cursor(-1)
  end, bopts)

  -- Directory navigation.
  -- Insert mode: Ctrl-variants to avoid clobbering filter text.
  -- Normal mode: vi-style single letters.
  vim.keymap.set("i", "<C-h>", go_parent, bopts)
  vim.keymap.set("i", "<C-l>", enter_dir, bopts) -- note: wipe-filter C-l is not mapped here
  vim.keymap.set("i", "<Left>", go_parent, bopts)
  vim.keymap.set("i", "<Right>", enter_dir, bopts)
  vim.keymap.set("n", "h", go_parent, bopts)
  vim.keymap.set("n", "l", enter_dir, bopts)
  vim.keymap.set("n", "-", go_parent, bopts)
  vim.keymap.set("n", "<Left>", go_parent, bopts)
  vim.keymap.set("n", "<Right>", enter_dir, bopts)

  -- <CR>: enter selected dir, or confirm move if list is empty.
  vim.keymap.set({ "i", "n" }, "<CR>", enter_or_confirm, bopts)

  -- Explicit confirm at current directory.
  vim.keymap.set({ "i", "n" }, "y", confirm_move, bopts)
  vim.keymap.set({ "i", "n" }, "<C-y>", confirm_move, bopts)

  -- Cancel.
  -- Insert <Esc>/<C-c>: stop insert FIRST, then schedule close.
  -- This ensures insert mode is cleanly exited before focus returns to the
  -- explorer — the single most important fix for the "unresponsive explorer" bug.
  local function cancel_insert()
    vim.cmd("stopinsert")
    vim.schedule(close)
  end
  vim.keymap.set("i", "<Esc>", cancel_insert, bopts)
  vim.keymap.set("i", "<C-c>", cancel_insert, bopts)
  vim.keymap.set("n", "<Esc>", close, bopts)
  vim.keymap.set("n", "q", close, bopts)

  -- Backspace: block deletion into the icon prefix zone.
  vim.keymap.set("i", "<BS>", function()
    if not (P.win and api.nvim_win_is_valid(P.win)) then
      return "<BS>"
    end
    return api.nvim_win_get_cursor(P.win)[2] <= #ICON_PREFIX and "" or "<BS>"
  end, { buffer = buf, silent = true, noremap = true, expr = true })

  -- Home: jump to start of filter text (column just after the icon).
  vim.keymap.set("i", "<Home>", function()
    if P.win and api.nvim_win_is_valid(P.win) then
      pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
    end
  end, bopts)

  -- C-u: wipe filter text, stay in insert.
  vim.keymap.set("i", "<C-u>", function()
    P.filter = ""
    api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
    P.cursor = 1
    apply_filter()
    paint_all()
    pin_cursor()
  end, bopts)

  -- ── Initial render + enter insert ────────────────────────────────────

  refresh_entries()
  pin_cursor()
  vim.cmd("startinsert!")
end

return M
