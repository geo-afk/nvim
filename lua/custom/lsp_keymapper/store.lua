--- lsp-keymapper/store.lua
--- Lightweight JSON-based persistence layer.
--- Bindings are stored in `stdpath("data")/lsp-keymapper/bindings.json`
--- as:  { ["<client_name>"] = { { cap_key, lhs }, … } }

local M = {}

local function data_path()
  return vim.fn.stdpath 'data' .. 'custom/lsp_keymapper/bindings.json'
end

--- Load all saved bindings from disk.
--- @return table<string, table[]>  keyed by client name
function M.load_all()
  local path = data_path()
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok or not content or #content == 0 then
    return {}
  end
  local raw = table.concat(content, '\n')
  local decoded = vim.fn.json_decode(raw)
  return type(decoded) == 'table' and decoded or {}
end

--- Persist a single binding entry for a client.
---
--- @param client_name  string  LSP client name, e.g. "lua_ls"
--- @param cap_key      string  Capability key, e.g. "hoverProvider"
--- @param lhs          string  The key sequence chosen by the user
function M.save(client_name, cap_key, lhs)
  local path = data_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  local all = M.load_all()
  local entries = all[client_name] or {}

  -- Remove any existing entry for this cap_key so we don't duplicate
  local filtered = {}
  for _, e in ipairs(entries) do
    if e.cap_key ~= cap_key then
      table.insert(filtered, e)
    end
  end

  table.insert(filtered, { cap_key = cap_key, lhs = lhs })
  all[client_name] = filtered

  local encoded = vim.fn.json_encode(all)
  vim.fn.writefile({ encoded }, path)
end

--- Return the saved bindings for a specific client.
---
--- @param client_name  string
--- @return table[]  list of { cap_key, lhs }
function M.load(client_name)
  local all = M.load_all()
  return all[client_name] or {}
end

--- Delete a single saved binding for a client.
---
--- @param client_name  string
--- @param cap_key      string
function M.delete(client_name, cap_key)
  local path = data_path()
  local all = M.load_all()
  local entries = all[client_name] or {}
  local filtered = {}
  for _, e in ipairs(entries) do
    if e.cap_key ~= cap_key then
      table.insert(filtered, e)
    end
  end
  all[client_name] = filtered
  vim.fn.writefile({ vim.fn.json_encode(all) }, path)
end

--- Wipe all saved bindings for a client (useful for resetting).
---
--- @param client_name  string
function M.clear(client_name)
  local path = data_path()
  local all = M.load_all()
  all[client_name] = nil
  vim.fn.writefile({ vim.fn.json_encode(all) }, path)
end

return M
