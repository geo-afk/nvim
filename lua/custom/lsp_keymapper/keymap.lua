--- lsp-keymapper/keymap.lua
--- Utilities for inspecting existing keymaps and registering new ones.

local M = {}

--- Retrieve all keymaps currently set in a buffer for the given modes.
--- Returns a flat table keyed by `mode..lhs` for fast lookups.
---
--- @param bufnr   integer  Buffer handle (0 = current)
--- @param modes   string[] Modes to inspect, e.g. { "n", "v" }
--- @return table<string, vim.api.keyset.get_keymap>
function M.get_buf_keymaps(bufnr, modes)
  bufnr = bufnr or 0
  modes = modes or { 'n', 'v', 'i' }

  local result = {}

  for _, mode in ipairs(modes) do
    -- Buffer-local maps
    local buf_maps = vim.api.nvim_buf_get_keymap(bufnr, mode)
    for _, map in ipairs(buf_maps) do
      local key = mode .. (map.lhs or '')
      result[key] = map
    end

    -- Global maps
    local global_maps = vim.api.nvim_get_keymap(mode)
    for _, map in ipairs(global_maps) do
      local key = mode .. (map.lhs or '')
      -- Buffer-local takes precedence; do not overwrite if already set
      if not result[key] then
        result[key] = map
      end
    end
  end

  return result
end

--- Check whether a given key sequence is already mapped in a buffer.
--- Returns the conflicting map entry, or nil if the key is free.
---
--- @param lhs    string   The key sequence to check, e.g. "gd" or "<leader>rn"
--- @param mode   string   The mode to check, e.g. "n"
--- @param bufnr  integer  Buffer handle (0 = current)
--- @return vim.api.keyset.get_keymap|nil
function M.find_conflict(lhs, mode, bufnr)
  bufnr = bufnr or 0
  local all = M.get_buf_keymaps(bufnr, { mode })
  -- Normalise by resolving <leader> etc. so comparisons are reliable
  local normalised = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  return all[mode .. lhs] or all[mode .. normalised] or nil
end

--- Describe a keymap entry as a short human-readable string.
---
--- @param map vim.api.keyset.get_keymap
--- @return string
function M.describe(map)
  if not map then
    return '(none)'
  end

  local rhs = map.rhs or map.callback and '[lua callback]' or '?'
  local src = map.buffer and map.buffer ~= 0 and 'buf-local' or 'global'
  return string.format("'%s' → %s [%s]", map.lhs, rhs, src)
end

--- Register a buffer-local keymap for a given LSP action.
---
--- @param bufnr   integer    Buffer handle
--- @param modes   string[]   Modes, e.g. { "n" }
--- @param lhs     string     Key sequence chosen by the user
--- @param fn      function   The LSP handler to bind
--- @param label   string     Description for `which-key` / docs
function M.set(bufnr, modes, lhs, fn, label)
  for _, mode in ipairs(modes) do
    vim.keymap.set(mode, lhs, fn, {
      buffer = bufnr,
      desc = label,
      noremap = true,
      silent = true,
    })
  end
end

--- Bulk-register a set of mappings from the persistent store.
--- `mappings` is a list of `{ lhs, cap_key }` records as persisted by the UI.
---
--- @param bufnr    integer
--- @param mappings table[]  Each entry: { lhs = string, cap_key = string }
--- @param registry table<string, LspCapabilityDef>
function M.apply_bulk(bufnr, mappings, registry)
  for _, entry in ipairs(mappings) do
    local def = registry[entry.cap_key]
    if def then
      M.set(bufnr, def.modes, entry.lhs, def.fn, def.label)
    end
  end
end

return M
