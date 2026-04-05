local cfg = require("custom.explorer.config")
local fn = vim.fn
local uv = vim.uv or vim.loop

local M = {}

local function default_path()
  return fn.stdpath("data") .. "/explorer/projects.json"
end

local function path()
  local projects = (cfg.current or cfg.defaults).projects or {}
  return projects.store_path or default_path()
end

local function recent_limit()
  local projects = (cfg.current or cfg.defaults).projects or {}
  return projects.recent_limit or 20
end

local function normalize(data)
  data = type(data) == "table" and data or {}
  data.version = 1
  data.pinned = type(data.pinned) == "table" and data.pinned or {}
  data.recent = type(data.recent) == "table" and data.recent or {}
  return data
end

function M.load()
  local p = path()
  local ok, content = pcall(fn.readfile, p)
  if not ok or not content or #content == 0 then
    return normalize({})
  end

  local ok_decode, decoded = pcall(fn.json_decode, table.concat(content, "\n"))
  if not ok_decode then
    return normalize({})
  end

  return normalize(decoded)
end

function M.save(data)
  local p = path()
  fn.mkdir(fn.fnamemodify(p, ":h"), "p")
  fn.writefile({ fn.json_encode(normalize(data)) }, p)
end

local function normalized_path(raw)
  if not raw or raw == "" then
    return nil
  end
  return fn.fnamemodify(fn.expand(raw), ":p")
end

local function dedupe_paths(items)
  local out = {}
  local seen = {}
  for _, raw in ipairs(items or {}) do
    local p = normalized_path(raw)
    if p and not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  return out
end

function M.get_pinned()
  return dedupe_paths(M.load().pinned)
end

function M.get_recent()
  return dedupe_paths(M.load().recent)
end

function M.is_pinned(raw)
  local path_to_check = normalized_path(raw)
  if not path_to_check then
    return false
  end
  for _, p in ipairs(M.get_pinned()) do
    if p == path_to_check then
      return true
    end
  end
  return false
end

function M.add_pinned(raw)
  local p = normalized_path(raw)
  if not p then
    return false
  end

  local data = M.load()
  data.pinned = dedupe_paths(vim.list_extend({ p }, data.pinned))
  M.save(data)
  return true
end

function M.remove_pinned(raw)
  local p = normalized_path(raw)
  if not p then
    return false
  end

  local data = M.load()
  local filtered = {}
  for _, item in ipairs(data.pinned) do
    local current = normalized_path(item)
    if current and current ~= p then
      filtered[#filtered + 1] = current
    end
  end
  data.pinned = filtered
  M.save(data)
  return true
end

function M.toggle_pinned(raw)
  if M.is_pinned(raw) then
    M.remove_pinned(raw)
    return false
  end
  M.add_pinned(raw)
  return true
end

function M.push_recent(raw)
  local p = normalized_path(raw)
  if not p then
    return
  end

  local data = M.load()
  local recent = { p }
  for _, item in ipairs(data.recent) do
    local current = normalized_path(item)
    if current and current ~= p then
      recent[#recent + 1] = current
    end
    if #recent >= recent_limit() then
      break
    end
  end
  data.recent = recent
  M.save(data)
end

function M.remove(raw)
  local p = normalized_path(raw)
  if not p then
    return false
  end

  local data = M.load()
  local function filter(list)
    local out = {}
    for _, item in ipairs(list) do
      local current = normalized_path(item)
      if current and current ~= p then
        out[#out + 1] = current
      end
    end
    return out
  end
  data.pinned = filter(data.pinned)
  data.recent = filter(data.recent)
  M.save(data)
  return true
end

function M.exists(raw)
  local p = normalized_path(raw)
  local st = p and uv.fs_stat(p) or nil
  return st and st.type == "directory" or false
end

return M
