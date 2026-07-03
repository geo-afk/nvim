-- lua/custom/loader/events.lua
-- Event-triggered module loading via Neovim autocmds.
--
-- Design principles:
--   • One autocmd per distinct (events × pattern) pair -- never per module.
--     Multiple modules that share the same trigger are batched under one autocmd.
--   • `once = true` everywhere: the autocmd fires, loads all subscribers, then
--     self-destructs.  Avoids the "100 autocmds that fire on every FileType" trap.
--   • The autocmd group is named deterministically so re-registration is safe
--     across hot-reloads.

local M = {}
local utils = require("custom.loader.utils")
local state = require("custom.loader.state")

-- Registered batch groups: group_key -> { augroup_name, subscriber_list }
local _groups = {}

-- ── Internal ──────────────────────────────────────────────────────────────────

local function group_key(events, pattern)
  return table.concat(events, ",") .. "|" .. (pattern or "*")
end

local function augroup_name(key)
  -- Sanitise: autocmd group names must not contain special chars.
  return "LoaderEv_" .. key:gsub("[^%w_]", "_"):sub(1, 60)
end

local function make_group(events, pattern)
  local key = group_key(events, pattern)
  if _groups[key] then
    return _groups[key]
  end

  local name = augroup_name(key)
  local aug = vim.api.nvim_create_augroup(name, { clear = true })
  local group = { key = key, name = name, id = aug, mods = {} }
  _groups[key] = group

  local is_filetype = false
  for _, e in ipairs(events) do
    if e == "FileType" then
      is_filetype = true
      break
    end
  end

  local ac_opts = {
    group = aug,
    once = not is_filetype,
    callback = function(ev)
      -- Guard: only trigger on normal buffers for FileType events
      if is_filetype and vim.bo[ev.buf].buftype ~= "" then
        return
      end

      -- Tear down the group before loading so modules can re-register if needed.
      pcall(vim.api.nvim_del_augroup_by_name, name)
      _groups[key] = nil

      local core = require("custom.loader.core")
      for _, mod in ipairs(group.mods) do
        core.load(mod, { trigger = ev.event })
      end
    end,
  }
  if pattern then
    ac_opts.pattern = pattern
  end

  local id = vim.api.nvim_create_autocmd(events, ac_opts)
  state.autocmd_ids[#state.autocmd_ids + 1] = id

  return group
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Trigger `mods` when any of `events` fire, optionally matching `pattern`.
---@param events  string|string[]
---@param mods    string[]
---@param pattern string|nil   autocmd pattern (e.g. "*.py")
function M.on_event(events, mods, pattern)
  events = utils.to_list(events)
  local group = make_group(events, pattern)
  for _, mod in ipairs(mods) do
    if not utils.list_contains(group.mods, mod) then
      group.mods[#group.mods + 1] = mod
    end
  end
end

--- Trigger `mods` when FileType matches any entry in `ft_list`.
---@param ft_list string|string[]
---@param mods    string[]
function M.on_filetype(ft_list, mods)
  ft_list = utils.to_list(ft_list)
  -- FileType pattern is a comma-joined glob list.
  M.on_event({ "FileType" }, mods, table.concat(ft_list, ","))
end

--- Trigger `mods` on BufReadPre/BufNewFile matching `patterns`.
---@param patterns string|string[]
---@param mods     string[]
function M.on_bufread(patterns, mods)
  patterns = utils.to_list(patterns)
  M.on_event({ "BufReadPre", "BufNewFile" }, mods, table.concat(patterns, ","))
end

return M
