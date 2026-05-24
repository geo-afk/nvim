local M = {}

local config = require("custom.statusline.config")
local hl = require("custom.statusline.highlights").hl
local utils = require("custom.statusline.utils")

local minimal_fts = {
  ["NvimTree"] = true,
  ["neo-tree"] = true,
  ["Telescope"] = true,
  ["TelescopePrompt"] = true,
  ["lazy"] = true,
  ["mason"] = true,
  ["help"] = true,
  ["qf"] = true,
  ["terminal"] = true,
  ["nofile"] = true,
  ["prompt"] = true,
  ["toggleterm"] = true,
}

local sections = {}
local stats = {
  renders = 0,
  last_width = 0,
  last_total = 0,
  last_dropped = {},
  last_degraded = {},
}

local ALWAYS_FRESH = { mode = true, cursor = true }

local function cache_key(sec, ctx)
  local bucket = math.floor((ctx.width or 80) / 8)
  return table.concat({ sec.id, ctx.bufnr or 0, bucket, ctx.active and "a" or "i" }, ":")
end

local function is_minimal_buf(bufnr)
  local ft = vim.bo[bufnr].filetype or ""
  local bt = vim.bo[bufnr].buftype or ""
  return minimal_fts[ft] or minimal_fts[bt] or false
end

local function normalize_variants(raw)
  if type(raw) == "string" then
    raw = { { text = raw } }
  end
  local out = {}
  for _, item in ipairs(raw or {}) do
    if item and item.text and item.text ~= "" then
      out[#out + 1] = item
    end
  end
  return out
end

function M.reset()
  sections = {}
end

function M.add(side, fn, id, opts)
  opts = opts or {}
  sections[#sections + 1] = {
    side = side,
    fn = fn,
    id = id or tostring(#sections + 1),
    priority = opts.priority or 50,
    required = opts.required or false,
    always_fresh = ALWAYS_FRESH[id] or false,
    dirty = true,
    cache = nil,
  }
end

function M.mark_dirty(id)
  for _, sec in ipairs(sections) do
    if sec.id == id then
      sec.dirty = true
      return
    end
  end
end

function M.mark_dirty_all()
  for _, sec in ipairs(sections) do
    if not sec.always_fresh then
      sec.dirty = true
    end
  end
end

local function get_variants(sec, ctx)
  local key = cache_key(sec, ctx)
  if sec.always_fresh or sec.dirty or not sec.cache or sec.cache_key ~= key then
    local ok, raw = pcall(sec.fn, ctx)
    sec.cache = ok and normalize_variants(raw) or {}
    sec.cache_key = key
    sec.dirty = false
  end
  return sec.cache
end

local function separator_for(width)
  local sep = config.options.separators
  if width < 56 then
    return sep.compact or " "
  end
  return sep.wide or " │ "
end

local function build_items(side, ctx)
  local items = {}
  for order, sec in ipairs(sections) do
    if sec.side == side then
      local variants = get_variants(sec, ctx)
      if #variants > 0 then
        if ctx.width < 50 and not sec.required then
          goto continue
        end
        local initial = 1
        if ctx.width < 50 then
          initial = sec.required and math.min(#variants, sec.id == "file" and 3 or #variants) or #variants
        elseif ctx.width < 74 then
          initial = math.min(#variants, 2)
        end
        items[#items + 1] = {
          id = sec.id,
          order = order,
          side = side,
          priority = sec.priority,
          required = sec.required,
          variants = variants,
          index = initial,
          text = variants[initial].text,
        }
      end
      ::continue::
    end
  end
  return items
end

local function total_width(left, right, sep)
  local function side_width(group)
    local parts = {}
    for _, item in ipairs(group) do
      if item.text and item.text ~= "" then
        parts[#parts + 1] = item.text
      end
    end
    return utils.statusline_width(utils.join(parts, sep))
  end
  return side_width(left) + side_width(right)
end

local function degrade_once(items, degraded, dropped)
  local candidate
  for _, item in ipairs(items) do
    local can_degrade = (tonumber(item.index) or 1) < #(item.variants or {})
    local can_drop = not item.required and item.text ~= ""
    if can_degrade or can_drop then
      if not candidate or item.priority < candidate.priority or (item.priority == candidate.priority and item.order > candidate.order) then
        candidate = item
      end
    end
  end
  if not candidate then
    return false
  end
  if (tonumber(candidate.index) or 1) < #(candidate.variants or {}) then
    candidate.index = candidate.index + 1
    candidate.text = candidate.variants[candidate.index].text
    degraded[candidate.id] = candidate.variants[candidate.index].name or tostring(candidate.index)
  else
    candidate.text = ""
    dropped[candidate.id] = true
  end
  return true
end

local function fit(left, right, budget, sep)
  local all = {}
  for _, item in ipairs(left) do
    all[#all + 1] = item
  end
  for _, item in ipairs(right) do
    all[#all + 1] = item
  end

  local degraded, dropped = {}, {}
  local guard = 0
  stats.last_fit_start = total_width(left, right, sep)
  stats.last_budget = budget
  while total_width(left, right, sep) > budget and guard < 80 do
    guard = guard + 1
    if not degrade_once(all, degraded, dropped) then
      break
    end
  end
  stats.last_degraded = degraded
  stats.last_dropped = dropped
  stats.last_fit_end = total_width(left, right, sep)
end

local function join_items(items, sep)
  local parts = {}
  for _, item in ipairs(items) do
    if item.text and item.text ~= "" then
      parts[#parts + 1] = item.text
    end
  end
  return utils.join(parts, sep)
end

local function minimal_render(bufnr)
  local label = (vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype:upper())
    or (vim.bo[bufnr].buftype ~= "" and vim.bo[bufnr].buftype:upper())
    or "BUFFER"
  return hl("StatusLineNC") .. " " .. hl("StatusLineFilePath") .. label .. hl("StatusLineNC") .. "%="
end

function M.render(winid)
  stats.renders = stats.renders + 1
  winid = (winid == 0 or not winid) and vim.api.nvim_get_current_win() or winid
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local active = (winid == vim.api.nvim_get_current_win())

  if is_minimal_buf(bufnr) then
    return minimal_render(bufnr)
  end

  local width = vim.api.nvim_win_get_width(winid)
  local base = active and hl("StatusLine") or hl("StatusLineNC")
  local ctx = { winid = winid, bufnr = bufnr, active = active, width = width }
  local sep = separator_for(width)
  local left = build_items("left", ctx)
  local right = build_items("right", ctx)
  local budget = math.max(8, width - (config.options.density.target_padding or 2))

  fit(left, right, budget, sep)

  local left_s = join_items(left, sep)
  local right_s = join_items(right, sep)
  stats.last_width = width
  stats.last_total = utils.statusline_width(left_s) + utils.statusline_width(right_s)
  stats.last_items = {}
  for _, item in ipairs(left) do
    stats.last_items[#stats.last_items + 1] = { id = item.id, index = item.index, variants = #item.variants, priority = item.priority, required = item.required }
  end
  for _, item in ipairs(right) do
    stats.last_items[#stats.last_items + 1] = { id = item.id, index = item.index, variants = #item.variants, priority = item.priority, required = item.required }
  end

  if width < 42 then
    sep = " "
  end
  return base .. left_s .. " %=" .. right_s
end

function M.debug()
  return vim.deepcopy(stats)
end

return M
