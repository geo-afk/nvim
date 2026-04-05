-- layout.lua
-- Floating-window geometry manager.
--
-- Responsibilities
--   • Measure ideal content width from the list of items
--   • Clamp width/height against editor dimensions
--   • Compute cursor-relative screen position
--   • Flip the float left / above when it would overflow the edge

local kinds = require("custom.code_action.kinds")

local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function clamp(v, lo, hi)
  return math.max(lo, math.min(v, hi))
end

---Display width of a string, honouring multibyte and double-width characters.
---@param s string
---@return integer
local function dw(s)
  return vim.fn.strdisplaywidth(s)
end

-- ── Width estimation ──────────────────────────────────────────────────────────

---Estimate the natural display width of one menu row for sizing purposes.
---This mirrors the renderer's layout without needing the full build step.
---@param item table  { action, client }
---@return integer
local function item_natural_width(item)
  local action = item.action
  local title = (action.title or "Code Action"):gsub("[\r\n]", " ")

  -- "  <icon> <title>  <★ ><client> "
  local icon_w = kinds.symbol_width()
  local prefix_w = 2 + icon_w + 1 -- "  <icon> "
  local pref_w = action.isPreferred and 2 or 0 -- "★ "
  local source_w = item.client and (dw(item.client.name) + 2) or 0 -- " <name> "
  local right_w = pref_w + source_w

  return prefix_w + dw(title) + 2 + right_w -- +2 for minimum padding
end

-- ── Public API ─────────────────────────────────────────────────────────────────

---Compute all geometry needed to open the floating window.
---
---@param items         table[]    list of { action, client } items
---@param source_win    integer    source window handle
---@param source_cursor integer[]  { row, col } 1-indexed (from nvim_win_get_cursor)
---@return table
---  {
---    width   : integer,  -- inner content width (border excluded)
---    height  : integer,  -- inner content height
---    row     : integer,  -- 0-indexed editor-relative row for nvim_open_win
---    col     : integer,  -- 0-indexed editor-relative col for nvim_open_win
---  }
function M.compute(items, source_win, source_cursor)
  -- ── Content dimensions ───────────────────────────────────────────────
  local max_natural = 0
  for _, item in ipairs(items) do
    max_natural = math.max(max_natural, item_natural_width(item))
  end

  local min_w = 42
  local max_w = math.max(math.floor(vim.o.columns * 0.55), min_w)
  local width = clamp(max_natural, min_w, max_w)

  local max_h = math.max(math.floor(vim.o.lines * 0.40), 4)
  local height = clamp(#items, 1, max_h)

  -- ── Screen position of the source cursor ────────────────────────────
  -- screenpos() returns 1-indexed; nvim_open_win wants 0-indexed editor coords.
  local sp = vim.fn.screenpos(source_win, source_cursor[1], source_cursor[2] + 1)
  local srow = (sp.row > 0 and sp.row or 1) - 1
  local scol = (sp.col > 0 and sp.col or 1) - 1

  -- Default: one row below the cursor, two columns to its right.
  local row = srow + 1
  local col = scol + 2

  -- ── Overflow guards ──────────────────────────────────────────────────
  -- +2 accounts for the border on both sides.
  if col + width + 2 > vim.o.columns then
    -- Flip left so the right edge of the float aligns with the cursor.
    col = math.max(scol - width - 2, 0)
  end

  if row + height + 2 > vim.o.lines then
    -- Flip above so the float does not disappear below the screen.
    row = math.max(srow - height - 1, 0)
  end

  row = math.max(row, 0)
  col = math.max(col, 0)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
  }
end

---Build the title value accepted by `nvim_open_win`.
---Returns a list of { text, hl_group } pairs so each segment can be
---independently coloured — the main label uses the title background,
---and each source's count badge uses that source's foreground colour.
---
---@param items      table[]   list of { action, client } items
---@param highlights table     the highlights module (passed to avoid circular require)
---@return table  list of { string, string } pairs
function M.build_title(items, highlights)
  -- Tally actions per source in insertion order.
  local counts = {}
  local order = {}
  for _, item in ipairs(items) do
    local name = item.client and item.client.name or "?"
    if not counts[name] then
      counts[name] = 0
      table.insert(order, name)
    end
    counts[name] = counts[name] + 1
  end

  local HL = highlights.HL

  -- Main label segment (uses the title-bar background colour).
  local title = { { " 󰌶 Code Actions ", HL.TitleBg } }

  -- One badge per source, each coloured with that source's palette entry.
  for _, name in ipairs(order) do
    local src_hl = highlights.source_hl(name)
    table.insert(title, { string.format("  %s (%d) ", name, counts[name]), src_hl })
  end

  return title
end

---Build the footer hint string, choosing the shorter variant when the window
---is too narrow to fit the long one.
---@param width integer  inner content width
---@return string
function M.build_footer(width)
  local long = "  <CR> apply  <Esc>/<q> cancel  j/k navigate  "
  local short = "  <CR> apply  <Esc> cancel  "
  return (vim.fn.strdisplaywidth(long) <= width) and long or short
end

return M
