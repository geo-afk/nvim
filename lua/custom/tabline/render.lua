-- tabline/render.lua
-- High-performance visual renderer that implements slanted tabs,
-- project-accented underlines, mini.icons, buffer numbers, lock indicators,
-- precomputed zero-allocation string caches, and automatic responsive collapse.

local M = {}

local buffers_mod = nil
local projects_mod = nil
local highlights_mod = nil

local _config = nil

-- Delimiter characters for slanted active tab
local SLANT_LEFT = ""  -- U+E0BE (solid left triangle)
local SLANT_RIGHT = "" -- U+E0BC (solid right triangle)

-- ─── JIT Precomputed Click Directives ──────────────────────────────────────
local click_cache = {}
local close_cache = {}

local function get_click_str(b)
  local s = click_cache[b]
  if not s then
    s = "%" .. b .. "@v:lua.TablineHandleClick@"
    click_cache[b] = s
  end
  return s
end

local function get_close_str(b)
  local s = close_cache[b]
  if not s then
    s = "%" .. b .. "@v:lua.TablineHandleClose@"
    close_cache[b] = s
  end
  return s
end

-- ─── Dynamic Icon highlight cache ──────────────────────────────────────────
local active_icon_hl_cache = {}

local function get_active_icon_highlight(proj_color, icon_hl)
  local key = proj_color:gsub("#", "") .. "_" .. icon_hl
  local hl_name = "TabLineActiveIcon_" .. key
  if active_icon_hl_cache[key] then
    return hl_name
  end

  vim.api.nvim_set_hl(0, hl_name, {
    bg = proj_color,
    fg = "#11111b",
    bold = true,
  })

  active_icon_hl_cache[key] = true
  return hl_name
end

-- ─── Responsive Filename Compressor ──────────────────────────────────────
local function shrink_name(name)
  local tail = vim.fn.fnamemodify(name, ":t")
  local ext = vim.fn.fnamemodify(name, ":e")
  if ext ~= "" then
    local base = vim.fn.fnamemodify(name, ":t:r")
    return base:sub(1, 1) .. "." .. ext
  else
    return tail:sub(1, 1)
  end
end

-- ─── Display Name Cache ───────────────────────────────────────────────────
local name_cache = {
  fingerprint = nil,
  names = {},
}

local function is_valid_buf(bufnr)
  return type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr)
end

local function fingerprint(bufs)
  local t = {}
  for _, b in ipairs(bufs) do
    if is_valid_buf(b) then
      t[#t + 1] = b .. ":" .. vim.api.nvim_buf_get_name(b)
    end
  end
  return table.concat(t, "|")
end

function M.invalidate_name_cache()
  name_cache.fingerprint = nil
end

local function get_names(bufs, max_len)
  local valid_bufs = {}
  for _, b in ipairs(bufs) do
    if is_valid_buf(b) then
      valid_bufs[#valid_bufs + 1] = b
    end
  end

  local fp = fingerprint(valid_bufs)
  if name_cache.fingerprint == fp then
    return name_cache.names
  end

  local names = {}
  if buffers_mod then
    names = buffers_mod.get_display_names(valid_bufs, max_len)
  end
  name_cache.fingerprint = fp
  name_cache.names = names
  return names
end

-- ─── Visibility Window ────────────────────────────────────────────────────
local function compute_window(n_bufs, cur_idx, max_shown)
  if max_shown <= 0 or n_bufs <= max_shown then
    return 1, n_bufs, false, false
  end
  local half = math.floor(max_shown / 2)
  local start = math.max(1, cur_idx - half)
  local stop = start + max_shown - 1
  if stop > n_bufs then
    stop = n_bufs
    start = math.max(1, stop - max_shown + 1)
  end
  return start, stop, (start > 1), (stop < n_bufs)
end

-- ─── setup ────────────────────────────────────────────────────────────────
function M.setup(config)
  _config = config
  buffers_mod = require("custom.tabline.buffers")
  projects_mod = require("custom.tabline.projects")
  highlights_mod = require("custom.tabline.highlights")

  name_cache.fingerprint = nil
  name_cache.names = {}
  active_icon_hl_cache = {}
end

-- ─── render ───────────────────────────────────────────────────────────────
function M.render()
  if not _config then
    return ""
  end

  local bufs = buffers_mod.get_buffers()
  if #bufs == 0 then
    return "%#TabLineFill#"
  end

  local current = vim.api.nvim_get_current_buf()

  -- Find active buffer position
  local cur_idx = 1
  for i, b in ipairs(bufs) do
    if b == current then
      cur_idx = i
      break
    end
  end

  -- Slicing window calculation
  local si, ei, trunc_l, trunc_r = compute_window(#bufs, cur_idx, _config.max_buffers)

  local visible = {}
  for i = si, ei do
    visible[#visible + 1] = bufs[i]
  end

  local names = get_names(visible, _config.max_name_length)

  -- Estimate visual layout width for responsive triggers
  local total_cols = vim.o.columns
  local estimated_width = 0
  for _, b in ipairs(visible) do
    if is_valid_buf(b) then
      local n = names[b] or "[?]"
      -- Est. buffer number (3) + DevIcon (3) + name (len) + readonly (2) + close (2) + padding
      estimated_width = estimated_width + #n + 12
    end
  end

  -- Trigger smart collapse if spacing is restricted
  local collapse = (estimated_width > total_cols - 10) or (#bufs > 8)

  -- Render elements array
  local parts = {}
  local n = 0
  local function P(s)
    n = n + 1
    parts[n] = s
  end

  -- Left truncation symbol
  if trunc_l then
    P("%#TabLineTrunc#")
    P("  ")
  end

  local ok_mini, mini_icons = pcall(require, "mini.icons")

  -- Render visible buffers
  for i = si, ei do
    local b = bufs[i]

    if is_valid_buf(b) then
      local is_cur = (b == current)
      local is_ro = vim.bo[b].readonly or not vim.bo[b].modifiable

      -- 1. Project details & dynamic highlight generation
      local proj = projects_mod.detect(b)
      local sel_hl, edge_hl, close_hl, ro_hl

      if is_cur then
        sel_hl, edge_hl, close_hl, ro_hl = highlights_mod.get_project_highlights(proj.color)
      end

      -- 2. DevIcon from mini.icons
      local icon, icon_hl = "󰈙", "TabLine"
      if ok_mini then
        local name = vim.api.nvim_buf_get_name(b)
        if name ~= "" then
          local file_icon, file_hl = mini_icons.get("file", name)
          if file_icon then
            icon = file_icon
            icon_hl = file_hl
          end
        end
      end

      -- In inactive tabs under collapse pressure, we hide the icon
      local show_icon = not (collapse and not is_cur)

      -- 3. File name (shrink if inactive under collapse pressure)
      local raw_name = names[b] or "[?]"
      if collapse and not is_cur then
        raw_name = shrink_name(raw_name)
      end
      local clean_name = raw_name:gsub("%%", "%%%%")

      -- ─── Tab Rendering ───

      -- Tab Separator between inactive tabs
      if i > si and not is_cur and bufs[i - 1] ~= current then
        P("%#TabLineSep#")
        P("│")
      end

      if is_cur then
        -- Active slanted tab start
        P("%#" .. edge_hl .. "#")
        P(SLANT_LEFT)

        -- Active container body
        P("%#" .. sel_hl .. "#")
        P(get_click_str(b))

        -- Optional Buffer Number
        if _config.show_bufnr then
          P(" " .. b .. " ")
        else
          P(" ")
        end

        -- DevIcon with native colors and project active background matching
        local active_icon_hl = get_active_icon_highlight(proj.color, icon_hl)
        P("%#" .. active_icon_hl .. "#")
        P(icon)

        -- Buffer Name
        P("%#" .. sel_hl .. "#")
        P(" " .. clean_name)

        -- Readonly status lock
        if is_ro then
          P(" %#" .. ro_hl .. "#󰌾%#" .. sel_hl .. "#")
        end

        -- Close icon
        if _config.show_close then
          P(" %#" .. close_hl .. "#")
          P(get_close_str(b))
          P(_config.close_icon)
          P("%X")
        end

        P(" ")
        P("%X") -- End click target

        -- Active slanted tab end
        P("%#" .. edge_hl .. "#")
        P(SLANT_RIGHT)
      else
        -- Inactive tab body
        P("%#TabLine#")
        P(get_click_str(b))

        -- Optional Buffer Number
        if _config.show_bufnr then
          P("  " .. b .. " ")
        else
          P("  ")
        end

        -- Inactive Icon (rendered in its standard highlight, if not collapsed)
        if show_icon then
          P("%#" .. icon_hl .. "#")
          P(icon)
          P("%#TabLine#")
        end

        -- Filename
        P(" " .. clean_name)

        -- Readonly status lock
        if is_ro then
          P(" %#TabLineReadOnly#󰌾%#TabLine#")
        end

        -- Close icon (hidden on inactive tabs under collapse pressure)
        if _config.show_close and not (collapse and not is_cur) then
          P(" %#TabLineClose#")
          P(get_close_str(b))
          P(_config.close_icon)
          P("%X")
        end

        P(" ")
        P("%X") -- End click target
      end
    end
  end

  -- Right truncation symbol
  if trunc_r then
    P("%#TabLineTrunc#")
    P("  ")
  end

  P("%#TabLineFill#")
  return table.concat(parts)
end

return M
