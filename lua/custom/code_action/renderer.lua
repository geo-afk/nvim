-- renderer.lua
-- Builds display text for each menu row, computes byte-accurate highlight
-- segment offsets, applies buffer highlights, and draws a virtual scrollbar.
--
-- Row layout (no index numbers):
--
--   "  <icon> <title> ···padding··· <★ ><source> "
--   │  │      │                     │    │
--   │  kind   action title          pref source label (per-client colour)
--   └─ 2-space left indent

local kinds = require("custom.code_action.kinds")
local highlights = require("custom.code_action.highlight")

local M = {}
local HL = highlights.HL
local NS = highlights.NS

-- ── Helpers ──────────────────────────────────────────────────────────────────

---Display width of a string (handles multibyte / wide chars).
local function dw(s)
  return vim.fn.strdisplaywidth(s)
end

-- ── Line builder ──────────────────────────────────────────────────────────────

---Build one display row for a code action item.
---Returns both the final text string and byte-offset metadata used by the
---highlight pass (nvim_buf_add_highlight takes byte, not character, positions).
---
---@param item  table    { action, client }
---@param width integer  inner window width (border excluded)
---@return table
---  {
---    text : string,
---    segs : {
---      icon_start   : integer,   -- byte start of the kind icon
---      icon_end     : integer,   -- byte end   of the kind icon
---      pref_start   : integer,   -- byte start of "★ " (preferred marker)
---      pref_end     : integer,   -- byte end   of "★ "
---      source_start : integer,   -- byte start of the source label
---      has_source   : boolean,
---      preferred    : boolean,
---      disabled     : boolean,
---      source_hl    : string,    -- HL group for the source label
---    }
---  }
function M.build_line(item, width)
  local action = item.action
  local raw_title = (action.title or "Code Action"):gsub("[\r\n]", " ")
  local icon = kinds.get(action.kind)
  local client_name = item.client and item.client.name or nil
  local pref = action.isPreferred == true
  local disabled = action.disabled ~= nil

  -- ── Fixed-width segments ────────────────────────────────────────────
  -- Prefix: two spaces + icon + one space
  local prefix = "  " .. icon .. " "
  -- Preferred star marker (★ is U+2605, 3 UTF-8 bytes + 1 space = 4 bytes)
  local pref_str = pref and "★ " or ""
  -- Source label: "<name> " (trailing space for breathing room)
  local src_str = client_name and (client_name .. " ") or ""
  local right = pref_str .. src_str

  -- ── Title truncation ────────────────────────────────────────────────
  local prefix_dw = dw(prefix)
  local right_dw = dw(right)
  local avail_dw = math.max(width - prefix_dw - right_dw, 4)

  local title = raw_title
  if dw(title) > avail_dw then
    title = vim.fn.strcharpart(title, 0, math.max(avail_dw - 1, 1)) .. "…"
  end

  -- ── Padding (pushes right segment flush to the window edge) ─────────
  local pad_count = math.max(width - prefix_dw - dw(title) - right_dw, 1)
  local pad_str = string.rep(" ", pad_count)

  local full_line = prefix .. title .. pad_str .. right

  -- ── Byte offsets ────────────────────────────────────────────────────
  -- All segment lengths below are in *bytes*, not display columns, because
  -- nvim_buf_add_highlight uses byte positions.
  --
  -- "  "          = 2 bytes  (ASCII spaces)
  -- icon          = #icon bytes (Nerd Font glyph, typically 3 bytes UTF-8)
  -- " "           = 1 byte
  -- title         = #title bytes (may contain multibyte)
  -- pad_str       = pad_count bytes (ASCII spaces)
  -- pref_str      = #pref_str bytes (★ = 3 bytes + space = 4; "" = 0)
  -- src_str       = #src_str bytes  (client name + space)

  local b_icon_start = 2 -- after "  "
  local b_icon_end = b_icon_start + #icon
  local b_title_start = b_icon_end + 1 -- after " "
  local b_title_end = b_title_start + #title
  local b_pad_end = b_title_end + pad_count
  local b_pref_start = b_pad_end
  local b_pref_end = b_pref_start + #pref_str
  local b_source_start = b_pref_end

  return {
    text = full_line,
    segs = {
      icon_start = b_icon_start,
      icon_end = b_icon_end,
      pref_start = b_pref_start,
      pref_end = b_pref_end,
      source_start = b_source_start,
      has_source = client_name ~= nil,
      preferred = pref,
      disabled = disabled,
      source_hl = highlights.source_hl(client_name),
    },
  }
end

-- ── Highlight applicator ──────────────────────────────────────────────────────

---Apply extmark-based highlights to the buffer for every item row.
---Must be called after the buffer has been populated with lines.
---@param buf      integer
---@param items    table[]   list of { action, client } items
---@param displays table[]   parallel list returned by build_line
function M.apply_highlights(buf, items, displays)
  for i = 1, #items do
    local d = displays[i]
    local s = d.segs
    local row = i - 1 -- 0-indexed buffer row

    -- Kind icon (special colour)
    vim.api.nvim_buf_add_highlight(buf, NS, HL.Kind, row, s.icon_start, s.icon_end)

    -- Preferred star (diagnostic-hint colour)
    if s.preferred then
      vim.api.nvim_buf_add_highlight(buf, NS, HL.Preferred, row, s.pref_start, s.pref_end)
    end

    -- Source label (per-client palette colour)
    if s.has_source then
      vim.api.nvim_buf_add_highlight(buf, NS, s.source_hl, row, s.source_start, -1)
    end

    -- Disabled overlay applied last so it wins over all other colours.
    if s.disabled then
      vim.api.nvim_buf_add_highlight(buf, NS, HL.Disabled, row, 0, -1)
    end
  end
end

-- ── Virtual scrollbar ─────────────────────────────────────────────────────────

local SCROLLBAR_NS = vim.api.nvim_create_namespace("CodeActionMenuScrollbar")

---Draw (or redraw) a right-aligned virtual-text scrollbar.
---Called once on open and again on CursorMoved so the thumb tracks the view.
---No-ops silently when the entire list fits in the window.
---@param buf    integer
---@param win    integer
---@param count  integer  total number of items
function M.draw_scrollbar(buf, win, count)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  local win_h = vim.api.nvim_win_get_height(win)
  if win_h >= count then
    -- Everything fits; clear any previous scrollbar and bail out.
    vim.api.nvim_buf_clear_namespace(buf, SCROLLBAR_NS, 0, -1)
    return
  end

  -- Top visible line (1-indexed → convert to 0-indexed offset)
  local top = vim.fn.line("w0", win) - 1
  local range = math.max(count - win_h, 1)

  -- Thumb proportional size and position within the track.
  local thumb_h = math.max(1, math.floor(win_h * win_h / count))
  local thumb_top = math.floor(top / range * (win_h - thumb_h))
  thumb_top = math.min(thumb_top, win_h - thumb_h)

  vim.api.nvim_buf_clear_namespace(buf, SCROLLBAR_NS, 0, -1)

  for r = 0, win_h - 1 do
    local in_thumb = r >= thumb_top and r < thumb_top + thumb_h
    vim.api.nvim_buf_set_extmark(buf, SCROLLBAR_NS, r, 0, {
      virt_text = { { in_thumb and "▐" or " ", in_thumb and HL.Scrollbar or HL.ScrollTrack } },
      virt_text_pos = "right_align",
      priority = 200,
    })
  end
end

return M
