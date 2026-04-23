local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local tree = require("custom.explorer.tree")
local ui = require("custom.explorer.ui")

local api = vim.api
local fn = vim.fn

local M = {}

local P = {
  buf = nil,
  win = nil,
  return_win = nil,
  filter = "",
  cursor = 1,
  current_dir = nil,
  on_confirm = nil,
  entries = {},
  filtered = {},
}

local NS = api.nvim_create_namespace("explorer_move_picker")
local ICON_PREFIX = "     "
local SEARCH_ICON = " 󰉋  "
local PLACEHOLDER = "filter folders..."

local function restore_focus(target)
  if not (target and api.nvim_win_is_valid(target)) and S.win and api.nvim_win_is_valid(S.win) then
    target = S.win
  end
  if target and api.nvim_win_is_valid(target) then
    pcall(api.nvim_set_current_win, target)
  end
end

local function reset_state()
  if P.win and api.nvim_win_is_valid(P.win) then
    pcall(api.nvim_win_close, P.win, true)
  end
  if P.buf and api.nvim_buf_is_valid(P.buf) then
    pcall(api.nvim_buf_delete, P.buf, { force = true })
  end
  P.buf = nil
  P.win = nil
  P.return_win = nil
  P.filter = ""
  P.cursor = 1
  P.current_dir = nil
  P.on_confirm = nil
  P.entries = {}
  P.filtered = {}
end

local function close(opts)
  opts = opts or {}
  local target = P.return_win
  if api.nvim_get_mode().mode:sub(1, 1) == "i" then
    pcall(vim.cmd, "stopinsert")
  end
  reset_state()
  if opts.restore_focus ~= false then
    vim.schedule(function()
      restore_focus(target)
    end)
  end
end

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
      out[#out + 1] = {
        name = name,
        path = tree.join(root, name),
      }
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
  for _, entry in ipairs(P.entries) do
    if q == "" or entry.name:lower():find(q, 1, true) or entry.path:lower():find(q, 1, true) then
      P.filtered[#P.filtered + 1] = entry
    end
  end
  P.cursor = math.max(1, math.min(P.cursor, math.max(1, #P.filtered)))
end

local function paint_header()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end
  api.nvim_buf_clear_namespace(P.buf, NS, 0, 1)

  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    end_col = -1,
    hl_group = "ExplorerSearchBgActive",
    hl_eol = true,
    priority = 5,
  })
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    virt_text = { { SEARCH_ICON, "ExplorerSearchIconActive" } },
    virt_text_pos = "overlay",
    priority = 100,
  })
  if P.filter == "" then
    pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, #ICON_PREFIX, {
      virt_text = { { PLACEHOLDER, "ExplorerSearchPlaceholder" } },
      virt_text_pos = "overlay",
      priority = 50,
    })
  end
  pcall(api.nvim_buf_set_extmark, P.buf, NS, 0, 0, {
    virt_text = { { " target: " .. relative_to_root(P.current_dir) .. " ", "ExplorerSearchCount" } },
    virt_text_pos = "right_align",
    priority = 70,
  })
end

local function paint_items()
  if not (P.buf and api.nvim_buf_is_valid(P.buf)) then
    return
  end

  local lines = { "   .." }
  local marks = {
    { kind = "vt", row = 1, col = 3, vt = { { "󰉋 ", "ExplorerDirectory" } }, pos = "overlay", pri = 25 },
  }

  if #P.filtered == 0 then
    lines[#lines + 1] = '   No folders match "' .. P.filter .. '".'
    marks[#marks + 1] = { kind = "hl", row = 2, cs = 0, ce = -1, hl = "Comment", eol = true, pri = 10 }
  else
    for idx, entry in ipairs(P.filtered) do
      local row = idx + 1
      local is_current = idx == P.cursor
      lines[#lines + 1] = "     " .. entry.name
      if is_current then
        marks[#marks + 1] = { kind = "hl", row = row, cs = 0, ce = -1, hl = "ExplorerCursorLine", eol = true, pri = 10 }
        marks[#marks + 1] = {
          kind = "vt",
          row = row,
          col = 0,
          vt = { { "► ", "ExplorerDirectory" } },
          pos = "overlay",
          pri = 30,
        }
      end
      marks[#marks + 1] = {
        kind = "vt",
        row = row,
        col = 2,
        vt = { { "󰉋 ", "ExplorerDirectory" } },
        pos = "overlay",
        pri = 25,
      }
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

  for _, mark in ipairs(marks) do
    if mark.kind == "hl" then
      pcall(api.nvim_buf_set_extmark, P.buf, NS, mark.row, mark.cs, {
        end_col = mark.ce,
        hl_group = mark.hl,
        hl_eol = mark.eol,
        priority = mark.pri,
      })
    else
      pcall(api.nvim_buf_set_extmark, P.buf, NS, mark.row, mark.col, {
        virt_text = mark.vt,
        virt_text_pos = mark.pos,
        priority = mark.pri,
      })
    end
  end
end

local function paint_all()
  paint_header()
  paint_items()
end

local function refresh_entries()
  P.entries = scan_dirs(P.current_dir)
  apply_filter()
  paint_all()
  if P.win and api.nvim_win_is_valid(P.win) and api.nvim_get_mode().mode:sub(1, 1) == "i" then
    pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
  end
end

local function move_cursor(delta)
  if #P.filtered == 0 then
    return
  end
  if delta == 0 then
    return
  end
  P.cursor = ((P.cursor - 1 + delta) % #P.filtered) + 1
  paint_items()
  if P.win and api.nvim_win_is_valid(P.win) and api.nvim_get_mode().mode:sub(1, 1) == "i" then
    pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
  end
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

-- <CR> smart behaviour:
--   • If a directory is highlighted in the list → navigate into it.
--   • If the list is empty (no subdirs, or filter yields nothing) → confirm
--     the move to the currently displayed directory.
local function enter_or_confirm()
  local entry = current_entry()
  if entry then
    enter_dir()
  else
    confirm_move()
  end
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

function M.open(opts)
  opts = opts or {}
  close({ restore_focus = false })
  ui.ensure_hl()

  P.current_dir = opts.start_dir or S.root
  P.on_confirm = opts.on_confirm
  P.return_win = opts.return_win or api.nvim_get_current_win()

  local buf = api.nvim_create_buf(false, true)
  P.buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "explorer_popup"
  vim.bo[buf].modifiable = true
  vim.bo[buf].omnifunc = ""
  vim.bo[buf].completefunc = ""

  api.nvim_buf_set_lines(buf, 0, -1, false, { ICON_PREFIX })

  local editor = api.nvim_list_uis()[1]
  local editor_width = editor and editor.width or vim.o.columns
  local editor_height = editor and editor.height or vim.o.lines
  local width = math.min(84, editor_width - 8)
  local height = math.min(24, editor_height - 6)
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

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
    footer = " <CR>/l enter   h/- up   y confirm move   <Esc> cancel ",
    footer_pos = "center",
  })
  P.win = win

  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhl = table.concat({
    "Normal:ExplorerNormal",
    "FloatBorder:ExplorerPopupBorder",
    "FloatTitle:ExplorerPopupTitle",
    "FloatFooter:ExplorerPopupFooter",
  }, ",")

  api.nvim_create_autocmd("CursorMovedI", {
    buffer = buf,
    callback = function()
      if not (P.win and api.nvim_win_is_valid(P.win)) then
        return
      end
      if api.nvim_win_get_cursor(P.win)[1] ~= 1 then
        pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX + #P.filter })
      end
    end,
  })

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
        P.filter = ""
        api.nvim_buf_set_lines(buf, 0, 1, false, { ICON_PREFIX })
        pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
      end
      P.cursor = 1
      apply_filter()
      paint_all()
    end,
  })

  local bopts = { buffer = buf, silent = true, noremap = true }
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
  vim.keymap.set("n", "j", function()
    move_cursor(1)
  end, bopts)
  vim.keymap.set("n", "k", function()
    move_cursor(-1)
  end, bopts)
  vim.keymap.set({ "i", "n" }, "<CR>", enter_or_confirm, bopts)
  vim.keymap.set({ "i", "n" }, "l", enter_dir, bopts)
  vim.keymap.set({ "i", "n" }, "h", go_parent, bopts)
  vim.keymap.set({ "i", "n" }, "<Right>", enter_dir, bopts)
  vim.keymap.set({ "i", "n" }, "<Left>", go_parent, bopts)
  vim.keymap.set({ "i", "n" }, "-", go_parent, bopts)
  vim.keymap.set({ "i", "n" }, "<Tab>", enter_or_confirm, bopts)
  vim.keymap.set({ "i", "n" }, "<S-Tab>", go_parent, bopts)
  vim.keymap.set({ "i", "n" }, "y", confirm_move, bopts)
  vim.keymap.set({ "i", "n" }, "<Esc>", close, bopts)
  vim.keymap.set("n", "q", close, bopts)
  vim.keymap.set("i", "<BS>", function()
    if not (P.win and api.nvim_win_is_valid(P.win)) then
      return "<BS>"
    end
    return api.nvim_win_get_cursor(P.win)[2] <= #ICON_PREFIX and "" or "<BS>"
  end, { buffer = buf, silent = true, noremap = true, expr = true })
  vim.keymap.set("i", "<Home>", function()
    if P.win and api.nvim_win_is_valid(P.win) then
      pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
    end
  end, bopts)

  refresh_entries()
  pcall(api.nvim_win_set_cursor, P.win, { 1, #ICON_PREFIX })
  vim.cmd("startinsert!")
end

function M.close()
  close()
end

return M
