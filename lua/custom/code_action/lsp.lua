-- lsp.lua
-- All LSP-facing logic: fetching code actions from attached clients and
-- applying the chosen action (including codeAction/resolve support).

local M = {}

-- ── Compatibility shim ───────────────────────────────────────────────────────

---Neovim 0.10 renamed `get_active_clients` → `get_clients`.
---@param opts table
---@return table[]
local function lsp_get_clients(opts)
  if vim.lsp.get_clients then
    return vim.lsp.get_clients(opts)
  end
  ---@diagnostic disable-next-line: deprecated
  return vim.lsp.get_active_clients(opts)
end

-- ── Parameter helpers ────────────────────────────────────────────────────────

---Build an LSP `textDocument/codeAction` params table for a given client.
---Handles both cursor-position and visual-range invocations.
---@param client        table   LSP client object
---@param bufnr         integer
---@param winid         integer source window (used for make_range_params)
---@param range         table|nil  explicit LSP Range override
---@param visual_marks  table|nil  { start_pos, end_pos } 1-indexed
---@return table LSP params
local function build_params(client, bufnr, winid, range, visual_marks)
  local params

  if visual_marks and vim.lsp.util.make_given_range_params then
    params = vim.lsp.util.make_given_range_params(visual_marks[1], visual_marks[2], bufnr, client.offset_encoding)
  else
    params = vim.lsp.util.make_range_params(winid, client.offset_encoding)
  end

  if range then
    params.range = range
  end

  -- Attach diagnostics on the cursor line so servers can offer quick-fixes.
  local line = params.range and params.range.start and params.range.start.line
    or (vim.api.nvim_win_get_cursor(winid)[1] - 1)

  local diags = vim.diagnostic.get(bufnr, { lnum = line })
  params.context = {
    diagnostics = vim.tbl_map(function(d)
      return (d.user_data and d.user_data.lsp) or d
    end, diags),
    triggerKind = (vim.lsp.protocol.CodeActionTriggerKind or {}).Invoked or 1,
  }

  return params
end

-- ── Action application ───────────────────────────────────────────────────────

---Actually apply an already-resolved action object.
---@param action table  resolved LSP CodeAction
---@param client table|nil  LSP client (used for executeCommand)
local function do_apply(action, client)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client and client.offset_encoding or "utf-8")
  end

  if action.command then
    local cmd = type(action.command) == "table" and action.command or action
    if client then
      client.request("workspace/executeCommand", cmd, function(err)
        if err then
          vim.notify(
            "Code action command failed: " .. tostring(err.message),
            vim.log.levels.ERROR,
            { title = "Code Actions" }
          )
        end
      end)
    else
      vim.lsp.buf.execute_command(cmd)
    end
  end
end

---Apply a selected code action item.
---Handles the `codeAction/resolve` round-trip for lazy-loaded actions,
---and warns if the server has marked the action as disabled.
---@param item table  { action: table, client: table|nil }
function M.apply(item)
  local action = item.action
  local client = item.client

  if action.disabled then
    local reason = type(action.disabled) == "table" and action.disabled.reason or "unknown reason"
    vim.notify("Action is disabled: " .. reason, vim.log.levels.WARN, { title = "Code Actions" })
    return
  end

  -- If neither edit nor command is present, we need a resolve round-trip first.
  if not action.edit and not action.command then
    if client and client.supports_method("codeAction/resolve") then
      client.request("codeAction/resolve", action, function(err, resolved)
        if err or not resolved then
          vim.notify(
            "Failed to resolve action: " .. (err and tostring(err.message) or "empty response"),
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

-- ── Request ──────────────────────────────────────────────────────────────────

---Asynchronously fetch code actions from all attached LSP clients.
---All responses are gathered (with a 1.5 s timeout) before `callback` fires.
---@param bufnr        integer
---@param winid        integer      source window
---@param range        table|nil    explicit LSP Range (visual selection)
---@param visual_marks table|nil    { {row,col}, {row,col} } 1-indexed
---@param callback     function     called with { { action, client }[] }
function M.request(bufnr, winid, range, visual_marks, callback)
  local clients = lsp_get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })

  if vim.tbl_isempty(clients) then
    vim.notify("No LSP clients support code actions", vim.log.levels.INFO, { title = "Code Actions" })
    return
  end

  local items = {}
  local errors = {}
  local pending = #clients
  local finished = false
  local timer = vim.uv.new_timer()

  local function finish()
    if finished then
      return
    end
    finished = true

    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end

    vim.schedule(function()
      if vim.tbl_isempty(items) and #errors > 0 then
        vim.notify(table.concat(errors, "\n"), vim.log.levels.WARN, { title = "Code Actions" })
      end
      callback(items)
    end)
  end

  -- 1.5 s hard timeout so a stalled server never blocks the UI.
  timer:start(1500, 0, finish)

  for _, client in ipairs(clients) do
    local params = build_params(client, bufnr, winid, range, visual_marks)

    client.request("textDocument/codeAction", params, function(err, result)
      if finished then
        return
      end

      pending = pending - 1

      if err then
        table.insert(errors, string.format("[%s] %s", client.name, tostring(err.message or err)))
      elseif result then
        for _, action in ipairs(result) do
          table.insert(items, { action = action, client = client })
        end
      end

      if pending == 0 then
        finish()
      end
    end, bufnr)
  end
end

return M
