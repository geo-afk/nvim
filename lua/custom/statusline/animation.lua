-- Simple animation module (timer-based, windline-inspired; now freeze-proof)
local M = {}
M.enabled = false  -- Disabled by default to prevent freezes

local timer = nil
local mode_color_cache = {}

local function hsl_shift(color, h_delta, s_delta, l_delta)
  -- Use the hsl_adjust from components (or duplicate here)
  -- For brevity, simple delta on lightness (expand as needed)
  local r, g, b = color:match('#(%x%x)(%x%x)(%x%x)')
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  local l_delta = l_delta or 10  -- Default subtle lighten
  r, g, b = math.min(255, r + l_delta), math.min(255, g + l_delta), math.min(255, b + l_delta)
  return string.format('#%02x%02x%02x', r, g, b)
end

function M.animate_mode(mode_color)
  if not M.enabled then return mode_color end
  mode_color_cache.current = hsl_shift(mode_color, 10, 0.1, 5)  -- Hue + sat + light
  return mode_color_cache.current
end

function M.animate_scrollbar(sbar)
  if not M.enabled then return sbar end
  -- Pulse lightness (simple char shift)
  return sbar:gsub('.', function(c)
    return string.char(string.byte(c) + 1)  -- Subtle char "breathe" (e.g., ▁ -> ▂)
  end)
end

function M.toggle()
  M.enabled = not M.enabled
  vim.cmd('redrawstatus')
end

-- Timer for transitions (single step on mode change; no loop)
vim.api.nvim_create_autocmd('ModeChanged', {
  callback = function()
    if not M.enabled then return end
    if timer then timer:stop() end
    vim.schedule(function()
      -- Single subtle redraw for transition (no loop to avoid spam)
      vim.cmd('redrawstatus')
    end)
  end,
})

return M