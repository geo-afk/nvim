-- debugger_watches.lua — persistent watch expression list
local M = {}

local S = {
  watches = {}, -- { { expr, value, error } }
  on_update = nil, -- callback(watches)
}

function M.set_callback(fn)
  S.on_update = fn
end

local function project_root()
  local start = vim.fn.expand("%:p:h")
  local found = vim.fs.find({ "go.work", "go.mod", ".git" }, { upward = true, path = start })[1]
  return found and vim.fs.dirname(found) or vim.fn.getcwd()
end

local function save()
  local path = project_root() .. "/.nvim-debug-watches.json"
  local f = io.open(path, "w")
  if f then
    local items = {}
    for _, w in ipairs(S.watches) do
      table.insert(items, w.expr)
    end
    f:write(vim.json.encode(items))
    f:close()
  end
end

function M.load()
  local path = project_root() .. "/.nvim-debug-watches.json"
  local f = io.open(path, "r")
  if not f then
    return
  end
  local ok, items = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if ok and type(items) == "table" then
    S.watches = {}
    for _, expr in ipairs(items) do
      table.insert(S.watches, { expr = expr, value = "…", error = false })
    end
    if S.on_update then
      S.on_update(S.watches)
    end
  end
end

function M.add(expr)
  expr = vim.trim(expr or "")
  if expr == "" then
    return
  end
  for _, w in ipairs(S.watches) do
    if w.expr == expr then
      return
    end
  end
  table.insert(S.watches, { expr = expr, value = "…", error = false })
  save()
  if S.on_update then
    S.on_update(S.watches)
  end
end

function M.remove(expr)
  for i, w in ipairs(S.watches) do
    if w.expr == expr then
      table.remove(S.watches, i)
      break
    end
  end
  save()
  if S.on_update then
    S.on_update(S.watches)
  end
end

function M.get()
  return S.watches
end

function M.eval_all(session, frame_id)
  if #S.watches == 0 or not session or session.closed then
    return
  end
  local remaining = #S.watches
  for _, w in ipairs(S.watches) do
    session:request("evaluate", {
      expression = w.expr,
      context = "watch",
      frameId = frame_id,
    }, function(resp)
      if resp.success and resp.body then
        w.value = tostring(resp.body.result or "")
        w.error = false
      else
        w.value = resp.message or "error"
        w.error = true
      end
      remaining = remaining - 1
      if remaining == 0 and S.on_update then
        S.on_update(S.watches)
      end
    end)
  end
end

return M
