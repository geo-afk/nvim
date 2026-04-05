-- window.lua
-- Floating-window creation, population, keymaps, and lifecycle management
-- for the code action picker.
--
-- This module owns a single-instance guard (`is_open`) so only one picker
-- can be on screen at a time; attempting to open a second one issues a
-- warning and returns early.

local highlights = require("custom.code_action.highlight")
local layout = require("custom.code_action.layout")
local renderer = require("custom.code_action.renderer")
local lsp = require("custom.code_action.lsp")

local M = {}
local HL = highlights.HL

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

-- ── Instance guard ────────────────────────────────────────────────────────────

local is_open = false

-- ── Main entry point ──────────────────────────────────────────────────────────

---Open the code action picker.
---@param items         table[]    list of { action, client } items
---@param source_win    integer    the window the user invoked the menu from
---@param source_buf    integer
---@param source_cursor integer[]  { row, col } 1-indexed
function M.open(items, source_win, source_buf, source_cursor)
  if is_open then
    vim.notify("Code action menu is already open", vim.log.levels.WARN, { title = "Code Actions" })
    return
  end

  if vim.tbl_isempty(items) then
    vim.notify("No code actions available", vim.log.levels.INFO, { title = "Code Actions" })
    return
  end

  is_open = true
  local count = #items

  -- ── Geometry ────────────────────────────────────────────────────────
  local geo = layout.compute(items, source_win, source_cursor)
  local title = layout.build_title(items, highlights)
  local footer = layout.build_footer(geo.width)

  -- ── Buffer ──────────────────────────────────────────────────────────
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "codeactionmenu"
  vim.bo[buf].swapfile = false

  -- ── Window ──────────────────────────────────────────────────────────
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = geo.row,
    col = geo.col,
    width = geo.width,
    height = geo.height,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "left",
    footer = footer,
    footer_pos = "center",
    zindex = 60,
    noautocmd = true,
  })

  -- ── Populate buffer ──────────────────────────────────────────────────
  local displays = {}
  local lines = {}

  for i, item in ipairs(items) do
    displays[i] = renderer.build_line(item, geo.width)
    lines[i] = displays[i].text
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- ── Window options ───────────────────────────────────────────────────
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].scrolloff = 0
  -- Blend the float body with the editor background for a "no background" look.
  vim.wo[win].winblend = 0
  vim.wo[win].winhighlight = table.concat({
    "Normal:" .. HL.Normal,
    "FloatBorder:" .. HL.Border,
    "FloatTitle:" .. HL.Title,
    "FloatFooter:" .. HL.Footer,
    "CursorLine:" .. HL.CursorLine,
  }, ",")

  -- ── Highlights + initial scrollbar ──────────────────────────────────
  renderer.apply_highlights(buf, items, displays)
  renderer.draw_scrollbar(buf, win, count)

  -- ── Lifecycle helpers ────────────────────────────────────────────────
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

  local function close()
    if closed then
      return
    end
    closed = true
    is_open = false
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    restore_focus()
  end

  local function execute(index)
    local item = items[index]
    if not item then
      return
    end
    -- Close first, then apply so window teardown completes before edits land.
    close()
    vim.schedule(function()
      lsp.apply(item)
    end)
  end

  local function choose()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    execute(vim.api.nvim_win_get_cursor(win)[1])
  end

  -- ── Navigation ──────────────────────────────────────────────────────
  local function nav(delta)
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local cur = vim.api.nvim_win_get_cursor(win)[1]
    local nxt = clamp(cur + delta, 1, count)
    vim.api.nvim_win_set_cursor(win, { nxt, 0 })
    -- Redraw scrollbar so the thumb tracks the new view position.
    renderer.draw_scrollbar(buf, win, count)
  end

  -- ── Keymaps ──────────────────────────────────────────────────────────
  local opts = { buffer = buf, silent = true, nowait = true }

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, opts)
  end

  -- Confirm / cancel
  map("<CR>", choose)
  map("<Esc>", close)
  map("q", close)
  map("<2-LeftMouse>", choose)
  map("<LeftMouse>", choose) -- single-click to select

  -- Directional navigation
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
  map("<Tab>", function()
    nav(1)
  end)
  map("<S-Tab>", function()
    nav(-1)
  end)
  map("<C-n>", function()
    nav(1)
  end)
  map("<C-p>", function()
    nav(-1)
  end)

  -- Jump to first / last
  map("gg", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      renderer.draw_scrollbar(buf, win, count)
    end
  end)
  map("G", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, { count, 0 })
      renderer.draw_scrollbar(buf, win, count)
    end
  end)

  -- Half-page scroll analogues (Ctrl-d / Ctrl-u)
  map("<C-d>", function()
    nav(math.floor(geo.height / 2))
  end)
  map("<C-u>", function()
    nav(-math.floor(geo.height / 2))
  end)

  -- ── Auto-close autocmds ──────────────────────────────────────────────

  -- Close when focus leaves the picker buffer (e.g. mouse click outside).
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  -- Close if the source window is closed while the menu is open.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(source_win),
    once = true,
    callback = function()
      if not closed then
        close()
      end
    end,
  })

  -- Redraw the scrollbar on every cursor move so the thumb stays accurate
  -- when the user pages through a long list.
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if not closed then
        renderer.draw_scrollbar(buf, win, count)
      end
    end,
  })
end

return M
