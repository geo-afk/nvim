-- =============================================================================
-- statusline/components/cursor.lua
-- Cursor position, file progress, and visual progress-bar ruler.
-- =============================================================================

local M = {}
local hl = require("custom.statusline.highlights").hl
local utils = require("custom.statusline.utils")

-- ---------------------------------------------------------------------------
-- Progress-bar characters (block elements)
-- ---------------------------------------------------------------------------
-- local BAR_FILL = "━"
-- local BAR_HALF = "─"
-- local BAR_EMPTY = "·"

-- local BAR_FILL = '█' -- full
-- local BAR_HALF = '▀' -- upper half
-- local BAR_EMPTY = ' ' -- space (clean empty)

-- local BAR_FILL = "■" -- black square
-- local BAR_HALF = "◧" -- square with left half black
-- local BAR_EMPTY = "□" -- white square
--
-- -- 1. Simple dots (minimal)
-- local BAR_FILL = "●"
-- local BAR_HALF = "○"
-- local BAR_EMPTY = "·"
--
-- -- 2. Circles (clear distinction)
-- local BAR_FILL = "◉"
-- local BAR_HALF = "◌"
-- local BAR_EMPTY = "○"
--
-- -- 3. Blocks (chunky)
-- local BAR_FILL = "▓"
-- local BAR_HALF = "▒"
-- local BAR_EMPTY = "░"
--
-- -- 4. Arrows (progressive)
-- local BAR_FILL = "▶"
-- local BAR_HALF = "▷"
-- local BAR_EMPTY = "·"
--
-- -- 5. Diamonds
-- local BAR_FILL = "◆"
-- local BAR_HALF = "◇"
-- local BAR_EMPTY = "·"
--
-- -- 6. Stars
-- local BAR_FILL = "★"
-- local BAR_HALF = "☆"
-- local BAR_EMPTY = "·"
--
-- -- 7. Triangles
-- local BAR_FILL = "▲"
-- local BAR_HALF = "△"
-- local BAR_EMPTY = "·"
--
-- -- 8. Checkmarks (good for task progress)
-- local BAR_FILL = "✔"
-- local BAR_HALF = "●"
-- local BAR_EMPTY = "○"
--
-- -- 9. Custom blocks (vertical)
-- local BAR_FILL = "▮"
-- local BAR_HALF = "▯"
-- local BAR_EMPTY = "·"
--
-- -- 10. Thick dots
-- local BAR_FILL = "⬤"
-- local BAR_HALF = "◔"
-- local BAR_EMPTY = "◑"
--
-- -- 11. Squares with border
local BAR_FILL = "◼"
local BAR_HALF = "◧"
local BAR_EMPTY = "◻"
--
-- -- 12. Slanted (modern look)
-- local BAR_FILL = "▰"
-- local BAR_HALF = "▱"
-- local BAR_EMPTY = "·"

local BAR_SEGMENTS = 8 -- total cells in the mini-bar

--- Build a compact N-cell progress bar representing `pct` (0–100).
local function progress_bar(pct)
  -- Each segment represents 100/N %, sub-cell precision via half-block.
  local filled_f = (pct / 100) * BAR_SEGMENTS
  local filled = math.floor(filled_f)
  local frac = filled_f - filled

  local bar = {}
  for i = 1, BAR_SEGMENTS do
    if i <= filled then
      bar[i] = hl("StatusLineRulerFill") .. BAR_FILL
    elseif i == filled + 1 and frac >= 0.5 then
      bar[i] = hl("StatusLineRulerFill") .. BAR_HALF
    else
      bar[i] = hl("StatusLineRulerEmpty") .. BAR_EMPTY
    end
  end
  return table.concat(bar) .. hl("StatusLine")
end

--- Human-readable percentage label.
local function pct_label(pct)
  if pct <= 0 then
    return "TOP"
  end
  if pct >= 100 then
    return "BOT"
  end
  return string.format("%2d%%%%", pct)
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------

function M.render(winid)
  local win_width = vim.api.nvim_win_get_width(winid)
  local compact = win_width < 80
  local very_compact = win_width < 55

  -- Cursor info from the window (not necessarily current window in inactive)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local line = cursor[1]
  local col = cursor[2] + 1 -- 1-based
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local pct = total > 0 and math.floor((line / total) * 100) or 0

  local pos_str = hl("StatusLineCursor") .. string.format(" %d:%d ", line, col) .. hl("StatusLine")

  if very_compact then
    return pos_str
  end

  local progress_str = hl("StatusLineProgress") .. pct_label(pct) .. hl("StatusLine")

  if compact then
    return utils.join({ pos_str, progress_str }, " ")
  end

  local bar_str = progress_bar(pct)

  return utils.join({ pos_str, progress_str, bar_str }, " ")
end

return M
