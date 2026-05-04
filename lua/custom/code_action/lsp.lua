-- lsp.lua
-- All LSP-facing logic: fetching code actions from attached clients and
-- applying the chosen action (including codeAction/resolve support).
--
-- Requires Neovim 0.10+ (vim.lsp.get_clients).

local M = {}

-- ── Parameter helpers ────────────────────────────────────────────────────────

---@param client vim.lsp.Client
---@param bufnr  integer
---@param winid  integer
---@param range? lsp.Range
---@param visual_marks? {[1]: integer[], [2]: integer[]}
---@return lsp.CodeActionParams & { [any]: any }
local function build_params(client, bufnr, winid, range, visual_marks)
  ---@type lsp.CodeActionParams & { [any]: any }
  local params

  if visual_marks and vim.lsp.util.make_given_range_params then
    params = vim.lsp.util.make_given_range_params(visual_marks[1], visual_marks[2], bufnr, client.offset_encoding)
  else
    params = vim.lsp.util.make_range_params(winid, client.offset_encoding)
  end

  if range then
    params.range = range
  end

  local line = params.range and params.range.start and params.range.start.line
    or (vim.api.nvim_win_get_cursor(winid)[1] - 1)

  -- Use vim.diagnostic.get (stable since 0.6; no deprecated sign/namespace APIs).
  local diags = vim.diagnostic.get(bufnr, { lnum = line })

  params.context = {
    diagnostics = vim.tbl_map(function(d)
      return (d.user_data and d.user_data.lsp) or d
    end, diags),
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
  }

  return params
end

-- ── Action application ───────────────────────────────────────────────────────

---@param action table   resolved LSP CodeAction
---@param client vim.lsp.Client|nil
local function do_apply(action, client)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client and client.offset_encoding or "utf-8")
  end

  if action.command then
    local cmd = type(action.command) == "table" and action.command or action
    if client then
      -- Use client:exec_cmd (0.10+) when available; fall back to request.
      if client.exec_cmd then
        client:exec_cmd(cmd, { bufnr = 0 }, function(err)
          if err then
            vim.notify(
              "Code action command failed: " .. tostring(err.message or err),
              vim.log.levels.ERROR,
              { title = "Code Actions" }
            )
          end
        end)
      else
        client:request("workspace/executeCommand", cmd, function(err)
          if err then
            vim.notify(
              "Code action command failed: " .. tostring(err.message or err),
              vim.log.levels.ERROR,
              { title = "Code Actions" }
            )
          end
        end)
      end
    else
      local c = vim.lsp.get_clients({ bufnr = 0 })[1]
      if c then
        if c.exec_cmd then
          c:exec_cmd(cmd)
        else
          c:request("workspace/executeCommand", cmd)
        end
      end
    end
  end
end

---Apply a selected code action item.
---Handles codeAction/resolve for lazy-loaded actions.
---@param item { action: table, client: vim.lsp.Client|nil, preview_action?: table }
function M.apply(item)
  local action = item.preview_action or item.action
  local client = item.client

  if action.disabled then
    local reason = type(action.disabled) == "table" and action.disabled.reason or "unknown reason"
    vim.notify("Action is disabled: " .. reason, vim.log.levels.WARN, { title = "Code Actions" })
    return
  end

  if not action.edit and not action.command then
    if client and client:supports_method("codeAction/resolve") then
      client:request("codeAction/resolve", action, function(err, resolved)
        if err or not resolved then
          vim.notify(
            "Failed to resolve action: " .. (err and tostring(err.message or err) or "empty response"),
            vim.log.levels.ERROR,
            { title = "Code Actions" }
          )
          return
        end
        do_apply(resolved, client)
      end)
      return
    end
  end

  do_apply(action, client)
end

---Resolve a code action for preview without applying it.
---@param item  { action: table, client: vim.lsp.Client|nil, preview_action?: table }
---@param callback fun(err: string|nil, action: table|nil)
function M.resolve_for_preview(item, callback)
  if item.preview_action then
    callback(nil, item.preview_action)
    return
  end

  local action = item.action
  local client = item.client

  if action.edit or action.command or action.disabled then
    item.preview_action = action
    callback(nil, action)
    return
  end

  if not client or not client:supports_method("codeAction/resolve") then
    item.preview_action = action
    callback(nil, action)
    return
  end

  client:request("codeAction/resolve", action, function(err, resolved)
    vim.schedule(function()
      if err then
        callback("Failed to resolve action: " .. tostring(err.message or err), nil)
        return
      end
      item.preview_action = resolved or action
      callback(nil, item.preview_action)
    end)
  end)
end

-- ── Request ──────────────────────────────────────────────────────────────────

---Asynchronously fetch code actions from all attached LSP clients.
---@param bufnr        integer
---@param winid        integer
---@param range?       lsp.Range
---@param visual_marks? {[1]: integer[], [2]: integer[]}
---@param timeout_ms?  integer   default 1500
---@param callback     fun(items: {action: lsp.CodeAction, client: vim.lsp.Client}[])
function M.request(bufnr, winid, range, visual_marks, timeout_ms, callback)
  -- vim.lsp.get_clients is stable since 0.10 (replaces deprecated buf_get_clients).
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })

  if vim.tbl_isempty(clients) then
    vim.notify("No LSP clients support code actions", vim.log.levels.INFO, { title = "Code Actions" })
    callback({})
    return
  end

  ---@type { action: lsp.CodeAction, client: vim.lsp.Client }[]
  local items = {}
  local errors = {}
  local pending = #clients
  local finished = false
  local timer = assert(vim.uv.new_timer())

  local function finish()
    if finished then
      return
    end
    finished = true
    timer:stop()
    timer:close()
    vim.schedule(function()
      if vim.tbl_isempty(items) and #errors > 0 then
        vim.notify(table.concat(errors, "\n"), vim.log.levels.WARN, { title = "Code Actions" })
      end
      callback(items)
    end)
  end

  timer:start(timeout_ms or 1500, 0, finish)

  for _, client in ipairs(clients) do
    local params = build_params(client, bufnr, winid, range, visual_marks)

    client:request("textDocument/codeAction", params, function(err, result)
      if finished then
        return
      end
      pending = pending - 1

      if err then
        errors[#errors + 1] = string.format("[%s] %s", client.name, tostring(err.message or err))
      elseif result then
        for _, action in ipairs(result) do
          items[#items + 1] = { action = action, client = client }
        end
      end

      if pending == 0 then
        finish()
      end
    end, bufnr)
  end
end

return M
