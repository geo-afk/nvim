-- lsp.lua
-- All LSP-facing logic: fetching code actions from attached clients and
-- applying the chosen action (including codeAction/resolve support).
--
-- Requires Neovim 0.10+ (vim.lsp.get_clients).

local M = {}

-- ── Parameter helpers ────────────────────────────────────────────────────────

---@param diagnostic table
---@return lsp.Range
local function diagnostic_range(diagnostic)
  if diagnostic.user_data and diagnostic.user_data.lsp and diagnostic.user_data.lsp.range then
    return diagnostic.user_data.lsp.range
  end

  local lnum = diagnostic.lnum or 0
  local col = diagnostic.col or 0
  local end_lnum = diagnostic.end_lnum or lnum
  local end_col = diagnostic.end_col or col

  return {
    ["start"] = { line = lnum, character = col },
    ["end"] = { line = end_lnum, character = end_col },
  }
end

---@param a lsp.Range
---@param b lsp.Range
---@return boolean
local function ranges_overlap(a, b)
  local a_start = a.start or a["start"]
  local a_end = a["end"] or a_start
  local b_start = b.start or b["start"]
  local b_end = b["end"] or b_start

  if a_end.line < b_start.line or b_end.line < a_start.line then
    return false
  end
  if a_end.line == b_start.line and a_end.character < b_start.character then
    return false
  end
  if b_end.line == a_start.line and b_end.character < a_start.character then
    return false
  end
  return true
end

---Convert a Neovim diagnostic to an LSP diagnostic, preserving all fields.
---@param diagnostic table
---@return table
local function lsp_diagnostic(diagnostic)
  if diagnostic.user_data and diagnostic.user_data.lsp then
    local d = diagnostic.user_data.lsp
    if d.range then
      return d
    end
  end

  -- Fallback if user_data.lsp is missing (e.g. from a non-LSP diagnostic source)
  -- Note: character offsets here might be incorrect if multibyte and no user_data.lsp
  return {
    range = diagnostic_range(diagnostic),
    severity = diagnostic.severity,
    code = diagnostic.code,
    source = diagnostic.source or "nvim",
    message = diagnostic.message,
    data = diagnostic.data,
  }
end

---@param bufnr integer
---@param range lsp.Range
---@param client_id integer|nil
---@return table[]
local function diagnostics_for_range(bufnr, range, client_id)
  local start_pos = range.start or range["start"]
  local end_pos = range["end"] or start_pos
  local point_range = start_pos.line == end_pos.line and start_pos.character == end_pos.character

  local all_diagnostics = vim.diagnostic.get(bufnr)
  local out = {}

  for _, diagnostic in ipairs(all_diagnostics) do
    -- Filter by client ID if provided (matching native behavior)
    local match_client = true
    if client_id and diagnostic.namespace then
      local ns = vim.diagnostic.get_namespace(diagnostic.namespace)
      -- Native Neovim diagnostic namespaces for LSP are typically named 'vim_lsp_<client_id>'
      -- or stored in user_data.
      if ns and ns.name then
        local ns_client_id = ns.name:match("vim_lsp_(%d+)")
        if ns_client_id and tonumber(ns_client_id) ~= client_id then
          match_client = false
        end
      end
    end

    if match_client then
      if point_range or ranges_overlap(range, diagnostic_range(diagnostic)) then
        out[#out + 1] = lsp_diagnostic(diagnostic)
      end
    end
  end

  return out
end

---@param winid integer
---@return lsp.Range
local function cursor_range(winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local line = math.max(cursor[1] - 1, 0)
  local character = math.max(cursor[2], 0)

  return {
    start = { line = line, character = character },
    ["end"] = { line = line, character = character },
  }
end

---@param client vim.lsp.Client
---@param bufnr  integer
---@param winid  integer
---@param range? lsp.Range
---@param visual_marks? {[1]: integer[], [2]: integer[]}
---@return lsp.CodeActionParams
local function build_params(client, bufnr, winid, range, visual_marks)
  ---@type lsp.CodeActionParams
  local params

  if visual_marks and vim.lsp.util.make_given_range_params then
    params = vim.lsp.util.make_given_range_params(visual_marks[1], visual_marks[2], bufnr, client.offset_encoding)
  else
    params = vim.lsp.util.make_range_params(winid, client.offset_encoding)
  end

  -- Ensure range is present (make_range_params might return position-only in some versions)
  if not params.range then
    params.range = range or cursor_range(winid)
  end
  params.position = nil

  params.context = {
    diagnostics = diagnostics_for_range(bufnr, params.range, client.id),
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
  local clients = vim.tbl_filter(function(client)
    return client:supports_method("textDocument/codeAction", bufnr)
  end, vim.lsp.get_clients({ bufnr = bufnr }))

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
