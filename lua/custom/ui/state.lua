local M = {}
local instances = {}

local State = {}
State.__index = State

function State:get(key, default)
  local value = self.values[key]
  if value == nil then
    return default
  end
  return value
end

function State:set(key, value)
  self.values[key] = value
  return value
end

function State:update(values)
  for key, value in pairs(values or {}) do
    self.values[key] = value
  end
  return self
end

function State:close()
  self.closed = true
  if self.on_close then
    pcall(self.on_close, self)
  end
  instances[self.id] = nil
end

function M.create(id, values)
  id = id or ("ui:" .. tostring(vim.uv.hrtime()))
  local state = setmetatable({
    id = id,
    values = values or {},
    closed = false,
  }, State)
  instances[id] = state
  return state
end

function M.get(id)
  return instances[id]
end

function M.destroy(id)
  local state = instances[id]
  if state then
    state:close()
  end
end

return M
