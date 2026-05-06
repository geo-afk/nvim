-- debugger_watches.lua — persistent watch expression list
local M = {}

local watches = {} -- { { expr, value, error } }
local on_update = nil -- callback(watches)

function M.set_callback(fn)
  on_update = fn
end

function M.add(expr)
  expr = vim.trim(expr or "")
  if expr == "" then
    return
  end
  for _, w in ipairs(watches) do
    if w.expr == expr then
      return
    end
  end
  table.insert(watches, { expr = expr, value = "…", error = false })
  if on_update then
    on_update(watches)
  end
end

function M.remove(expr)
  for i, w in ipairs(watches) do
    if w.expr == expr then
      table.remove(watches, i)
      break
    end
  end
  if on_update then
    on_update(watches)
  end
end

function M.get()
  return watches
end

function M.eval_all(session, frame_id)
  if #watches == 0 or not session or session.closed then
    return
  end
  local remaining = #watches
  for _, w in ipairs(watches) do
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
      if remaining == 0 and on_update then
        on_update(watches)
      end
    end)
  end
end

return M
