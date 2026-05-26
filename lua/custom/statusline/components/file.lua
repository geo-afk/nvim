-- =============================================================================
-- statusline/components/file.lua  (cached edition)
-- =============================================================================
--
-- PERFORMANCE FIX
-- ────────────────
-- The previous version called getfsize(), fnamemodify(), buf_line_count(),
-- and built format strings on every single eval() call — i.e. on every
-- keypress and scroll step.
--
-- This version caches the full rendered string per bufnr.
-- The cache entry is rebuilt only when explicitly invalidated via M.invalidate()
-- or M.invalidate_all(), which are called from autocmds in init.lua:
--   • BufEnter, BufWritePost, BufReadPost  → M.invalidate(bufnr)
--   • OptionSet(fileencoding,fileformat)   → M.invalidate(bufnr)
--   • VimResized                           → M.invalidate_all()
--
-- The hot path (eval on every scroll) now does: one table lookup + return.
-- =============================================================================

local M = {}
local hl = require("custom.statusline.highlights").hl
local utils = require("custom.statusline.utils")

-- ---------------------------------------------------------------------------
-- Cache:  [cache_key] = rendered_string
-- Cache key = bufnr .. ":" .. win_width_bucket
-- We bucket window widths into 5 tiers (xs / sm / md / lg / xl) so the
-- same buffer in windows of slightly different widths doesn't bust the cache,
-- but does rebuild when the display tier changes.
-- ---------------------------------------------------------------------------
local _cache = {}

local function width_bucket(w)
  if w < 50 then
    return "xs"
  elseif w < 75 then
    return "sm"
  elseif w < 100 then
    return "md"
  elseif w < 125 then
    return "lg"
  else
    return "xl"
  end
end

local function cache_key(bufnr, win_width)
  return bufnr .. ":" .. width_bucket(win_width)
end

function M.invalidate(bufnr)
  -- Remove all width-tier entries for this buffer.
  local prefix = tostring(bufnr) .. ":"
  for k in pairs(_cache) do
    if k:sub(1, #prefix) == prefix then
      _cache[k] = nil
    end
  end
end

function M.invalidate_all()
  _cache = {}
end

-- ---------------------------------------------------------------------------
-- Filetype icon map (Nerd Fonts v3)
-- ---------------------------------------------------------------------------
local ft_icons = {
  lua = "󰢱 ",
  python = "󰌠 ",
  javascript = "󰌞 ",
  typescript = "󰛦 ",
  rust = "󱘗 ",
  go = "󰟓 ",
  c = " ",
  cpp = " ",
  java = "󰬷 ",
  html = "󰌝 ",
  css = "󰌜 ",
  scss = "󰌜 ",
  json = "󰘦 ",
  yaml = "󰘦 ",
  toml = "󰘦 ",
  markdown = "󰍔 ",
  vim = " ",
  sh = "󱆃 ",
  bash = "󱆃 ",
  zsh = "󱆃 ",
  fish = "󱆃 ",
  dockerfile = "󰡨 ",
  makefile = " ",
  sql = "󰆼 ",
  tex = "󰙩 ",
  help = "󰞋 ",
  nix = " ",
  svelte = " ",
  vue = "󰡄 ",
  tsx = "󰛦 ",
  jsx = "󰌞 ",
  graphql = "󰡄 ",
  php = "󰌟 ",
  ruby = " ",
  elixir = " ",
  haskell = "󰲒 ",
  scala = " ",
  kotlin = "󱈙 ",
  swift = "󰛥 ",
  r = "󰟔 ",
  cs = "󰌛 ",
  zig = " ",
  dart = " ",
  git = "󰊢 ",
  gitconfig = "󰊢 ",
}
local DEFAULT_ICON = "󰈚 "

local function fmt_size(bytes)
  if bytes <= 0 then
    return "0B"
  end
  local units, i, s = { "B", "K", "M", "G" }, 1, bytes
  while s >= 1024 and i < #units do
    s = s / 1024
    i = i + 1
  end
  return i == 1 and string.format("%dB", s) or string.format("%.1f%s", s, units[i])
end

-- ---------------------------------------------------------------------------
-- Path formatting
-- ---------------------------------------------------------------------------
-- Default display: parent/.../filename   (always for paths with 3+ segments)
-- Only shows the full path when the path is 1-2 segments already short.
--
-- Tiers (applied in order):
--   3+ segments → parent/.../filename   e.g. lua/.../file.lua     ← DEFAULT
--   2  segments → parent/filename       e.g. plugins/telescope.lua
--   1  segment  → filename              e.g. init.lua
--   Overflow fallbacks (if even the default is too long for the window):
--     → .../filename
--     → filename (hard-truncated)
-- ---------------------------------------------------------------------------
local SEP = "/"

local function smart_path(name, max_w)
  if name == "" then
    return "[No Name]"
  end

  -- Relative to cwd, home collapsed to ~
  local rel = vim.fn.fnamemodify(name, ":~:.")

  -- On Windows fnamemodify returns backslashes; normalize to "/" so the split
  -- below works correctly on every platform.
  rel = rel:gsub("\\", "/")

  local parts = vim.split(rel, SEP, { plain = true })
  local n = #parts
  local fname = parts[n]

  -- 1 segment: bare filename, no directory at all
  if n == 1 then
    if #fname <= max_w then
      return fname
    end
    return fname:sub(1, max_w - 3) .. "..."
  end

  -- 2 segments: short enough to show in full — parent/filename
  if n == 2 then
    if #rel <= max_w then
      return rel
    end
    -- still too long: drop to filename only
    if #fname <= max_w then
      return fname
    end
    return fname:sub(1, max_w - 3) .. "..."
  end

  -- 3+ segments: DEFAULT = parent/.../filename
  local parent = parts[1]
  local tier2 = parent .. SEP .. "..." .. SEP .. fname

  if #tier2 <= max_w then
    return tier2
  end

  -- parent itself is very long: fall back to .../filename
  local tier3 = "..." .. SEP .. fname
  if #tier3 <= max_w then
    return tier3
  end

  -- Filename alone
  if #fname <= max_w then
    return fname
  end
  return fname:sub(1, max_w - 3) .. "..."
end

local function data(bufnr)
  local ft = vim.bo[bufnr].filetype or ""
  local name = vim.api.nvim_buf_get_name(bufnr)
  local size = name ~= "" and vim.fn.getfsize(name) or 0
  return {
    ft = ft,
    name = name,
    icon = ft_icons[ft:lower()] or DEFAULT_ICON,
    modified = vim.bo[bufnr].modified,
    readonly = vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable,
    size = math.max(0, size),
    lines = vim.api.nvim_buf_line_count(bufnr),
    enc = (vim.bo[bufnr].fileencoding ~= "" and vim.bo[bufnr].fileencoding) or vim.o.encoding or "utf-8",
    ff = vim.bo[bufnr].fileformat,
  }
end

local function flags(d)
  return (d.modified and (hl("StatusLineModified") .. "●" .. hl("StatusLine")) or "")
    .. (d.readonly and (hl("StatusLineReadonly") .. "󰌾" .. hl("StatusLine")) or "")
end

local function fileformat_label(ff)
  return ff == "unix" and "LF" or ff == "dos" and "CRLF" or "CR"
end

function M.variants(ctx)
  local win_width = ctx.width or 100
  local bufnr = ctx.bufnr
  local d = data(bufnr)
  local icon = hl("StatusLineFileIcon") .. d.icon .. hl("StatusLine")
  local state = flags(d)
  local full_path = hl("StatusLineFilePath")
    .. smart_path(d.name, math.max(18, math.floor(win_width * 0.32)))
    .. hl("StatusLine")
  local mid_path = hl("StatusLineFilePath")
    .. smart_path(d.name, math.max(14, math.floor(win_width * 0.23)))
    .. hl("StatusLine")
  local short_path = hl("StatusLineFilePath") .. smart_path(d.name, 18) .. hl("StatusLine")
  local name_only = hl("StatusLineFilePath") .. smart_path(vim.fn.fnamemodify(d.name, ":t"), 14) .. hl("StatusLine")
  local ft = d.ft ~= "" and (hl("StatusLineChipMuted") .. " " .. d.ft .. " " .. hl("StatusLine")) or ""
  local size = hl("StatusLineFileSize") .. fmt_size(d.size) .. hl("StatusLine")
  local lines = hl("StatusLineLineCount") .. "󰦕 " .. d.lines .. "L" .. hl("StatusLine")
  local enc = hl("StatusLineEncoding") .. d.enc:upper() .. hl("StatusLine")
  local ff = hl("StatusLineEncoding") .. fileformat_label(d.ff) .. hl("StatusLine")

  return {
    { name = "full", text = utils.join({ icon, full_path, state, size, lines, ft, enc, ff }, " ") },
    { name = "medium", text = utils.join({ icon, mid_path, state, lines, ft }, " ") },
    { name = "compact", text = utils.join({ icon, short_path, state }, " ") },
    { name = "minimal", text = utils.join({ icon, name_only, state }, " ") },
  }
end

-- ---------------------------------------------------------------------------
-- Build the rendered string (called once per cache miss)
-- ---------------------------------------------------------------------------
local function build(bufnr, win_width)
  local tier = width_bucket(win_width)

  local ft = vim.bo[bufnr].filetype or ""
  local icon = ft_icons[ft:lower()] or DEFAULT_ICON
  local name = vim.api.nvim_buf_get_name(bufnr)

  local icon_str = hl("StatusLineFileIcon") .. icon .. hl("StatusLine")

  -- Path budget: dynamic based on window width
  local path_max = math.max(12, math.floor(win_width * 0.25))
  if tier == "xs" then
    path_max = 15
  end
  local path_str = hl("StatusLineFilePath") .. smart_path(name, path_max) .. hl("StatusLine")

  local mod_str = vim.bo[bufnr].modified and (hl("StatusLineModified") .. "●" .. hl("StatusLine")) or ""
  local ro_str = (vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable)
      and (hl("StatusLineReadonly") .. "󰌾" .. hl("StatusLine"))
    or ""

  local parts = {}

  -- Minimal (xs): Icon, Path, Mod, RO
  if tier == "xs" then
    return utils.join({ icon_str, path_str, mod_str, ro_str }, " ")
  end

  -- Small (sm): Add Bufrnr, Size
  local bufnr_str = hl("StatusLineBufNr") .. "[" .. bufnr .. "]" .. hl("StatusLine")
  local size_bytes = vim.fn.getfsize(name)
  local size_str = hl("StatusLineFileSize") .. fmt_size(math.max(0, size_bytes)) .. hl("StatusLine")

  if tier == "sm" then
    return utils.join({ bufnr_str, icon_str, path_str, mod_str, ro_str, size_str }, " ")
  end

  -- Medium (md): Add LineCount
  local lines_str = hl("StatusLineLineCount")
    .. "󰦕 "
    .. vim.api.nvim_buf_line_count(bufnr)
    .. "L"
    .. hl("StatusLine")

  if tier == "md" then
    return utils.join({ bufnr_str, icon_str, path_str, mod_str, ro_str, size_str, lines_str }, " ")
  end

  -- Large (lg): Add FT
  local ft_str = ft ~= "" and (hl("StatusLineChipMuted") .. " " .. ft .. " " .. hl("StatusLine")) or ""

  if tier == "lg" then
    return utils.join({ bufnr_str, icon_str, path_str, mod_str, ro_str, size_str, lines_str, ft_str }, " ")
  end

  -- Extra Large (xl): Add Encoding, FF
  local enc = (vim.bo[bufnr].fileencoding ~= "" and vim.bo[bufnr].fileencoding) or vim.o.encoding or "utf-8"
  local ff = vim.bo[bufnr].fileformat
  local ff_label = ff == "unix" and "LF" or ff == "dos" and "CRLF" or "CR"

  local enc_str = hl("StatusLineEncoding") .. enc:upper() .. hl("StatusLine")
  local ff_str = hl("StatusLineEncoding") .. ff_label .. hl("StatusLine")

  return utils.join({
    bufnr_str,
    icon_str,
    path_str,
    mod_str,
    ro_str,
    size_str,
    lines_str,
    ft_str,
    enc_str,
    ff_str,
  }, " ")
end

-- ---------------------------------------------------------------------------
-- Public render (hot path: one table lookup, or build+cache on miss)
-- ---------------------------------------------------------------------------
function M.render(winid, bufnr, active, width)
  local win_width = width or vim.api.nvim_win_get_width(winid)
  local key = cache_key(bufnr, win_width)
  if _cache[key] then
    return _cache[key]
  end
  local s = build(bufnr, win_width)
  _cache[key] = s
  return s
end

return M
