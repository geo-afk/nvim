-- =============================================================================
-- lua/custom/template/completion.lua
-- Blink.cmp source that proxies completion requests to the virtual HTML
-- buffer's attached html LSP client.
--
-- How it works
--   When blink.cmp fires a completion request in a JS/TS buffer and the cursor
--   is inside an HTML template string, this source:
--     1. Asks custom.template for the current virtual HTML buffer + client.
--     2. Translates the cursor position to the HTML buffer's coordinate space.
--     3. Sends textDocument/completion to the HTML LSP on behalf of the HTML buf.
--     4. Returns the items to blink.cmp.
--
-- Registration
--   Call M.register() once after blink.cmp is set up.
--   This registers via blink.add_source_provider — do NOT also list this module
--   in the blink `providers` config with `module =` (that path expects new()).
-- =============================================================================

-- blink.cmp source class — must implement new() + source protocol methods.
local Source = {}
Source.__index = Source

local tmpl = require("custom.template")

---@return self
function Source.new()
  return setmetatable({}, Source)
end

--- Source protocol: should this source be active for the current buffer?
function Source:enabled()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local supported = {
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
  }
  if not supported[ft] then
    return false
  end
  return tmpl.get_html_buf(bufnr) ~= nil
end

--- Source protocol: get completions.
---@param ctx    table  blink context
---@param resolve fun(response: table|nil)
function Source:get_completions(ctx, resolve)
  local src_buf = vim.api.nvim_get_current_buf()
  local html_buf = tmpl.get_html_buf(src_buf)
  if not html_buf then
    return resolve(nil)
  end

  local client = tmpl.get_html_client(src_buf)
  if not client then
    return resolve(nil)
  end

  -- Translate cursor position from source → virtual HTML buffer coordinates.
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row0 = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]
  local html_row, html_col = tmpl.src_to_html_pos(src_buf, row0, col)
  if not html_row then
    return resolve(nil)
  end

  local params = {
    textDocument = { uri = vim.uri_from_bufnr(html_buf) },
    position = { line = html_row, character = html_col },
    context = { triggerKind = 1 },
  }

  client:request("textDocument/completion", params, function(err, result)
    if err or not result then
      return resolve(nil)
    end
    local items = result.items or result or {}
    -- Stamp each item so blink can distinguish the source.
    for _, item in ipairs(items) do
      item._tmpl_source = "html"
    end
    resolve({
      items = items,
      is_incomplete_forward = result.isIncomplete or false,
      is_incomplete_backward = false,
    })
  end, html_buf)
end

--- Source protocol: resolve a completion item for full docs/edits.
function Source:resolve(item, resolve)
  local src_buf = vim.api.nvim_get_current_buf()
  local client = tmpl.get_html_client(src_buf)
  if not client then
    return resolve(item)
  end
  local html_buf = tmpl.get_html_buf(src_buf)
  if not html_buf then
    return resolve(item)
  end
  client:request("completionItem/resolve", item, function(err, resolved)
    resolve((not err and resolved) or item)
  end, html_buf)
end

-- ── Registration ──────────────────────────────────────────────────────────────

local _registered = false

--- Register this source with blink.cmp (call once during setup).
--- Uses add_source_provider — does NOT require `module =` in blink config.
function Source.register()
  if _registered then
    return
  end
  local ok, blink = pcall(require, "blink.cmp")
  if not ok then
    return
  end
  if type(blink.add_source_provider) == "function" then
    local ok2, err = pcall(blink.add_source_provider, "html_template", Source)
    if not ok2 then
      -- Tolerate "already exists" (e.g. module hot-reloaded).
      if not tostring(err):find("already exists") then
        vim.notify("[template] blink provider register failed: " .. tostring(err), vim.log.levels.WARN)
      end
    end
    _registered = true
  end
end

return Source
