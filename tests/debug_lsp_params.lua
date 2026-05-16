local function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

-- Intercept LSP requests
local original_request = vim.lsp.buf_request
local intercepted = {}

_G.intercept_lsp = function()
  vim.lsp.buf_request = function(bufnr, method, params, callback)
    if method == "textDocument/codeAction" then
      table.insert(intercepted, { method = method, params = params })
    end
    return original_request(bufnr, method, params, callback)
  end
end

_G.get_intercepted = function()
  return intercepted
end

_G.clear_intercepted = function()
  intercepted = {}
end
