-- =============================================================================
-- lua/custom/template/init.lua
-- HTML template LSP support for vanilla-JS template-literal components.
--
-- What it does:
--   • Detects template strings containing HTML markup in JS/TS buffers.
--   • Creates (or reuses) a virtual scratch buffer with filetype=html that
--     contains just the HTML text of the current template region.
--   • Attaches vscode-html-language-server to that virtual buffer so you get
--     real HTML completions, hover docs and diagnostics while cursor is inside
--     any template string containing HTML.
--   • Keeps the virtual buffer in sync as you type (TextChanged autocmds).
--   • Forwards diagnostics from the virtual buffer back as virtual text on the
--     original JS/TS source buffer (with correct line offsets).
--
-- Setup
--   Call require("custom.template").setup() once (the loader in init.lua does
--   this via the `ft` trigger on javascript/typescript/tsx).
--
-- Public API
--   M.setup()            – wire autocmds and start the engine
--   M.get_html_buf()     – return current virtual HTML bufnr or nil
--   M.sync_now(bufnr)    – force-sync template for a given source bufnr
-- =============================================================================

local M = {}

-- ── Internal state ────────────────────────────────────────────────────────────

---@class TemplateState
---@field html_buf   integer          Virtual HTML buffer
---@field src_buf    integer          Source JS/TS buffer
---@field client_id  integer|nil      html LSP client id
---@field last_tmpl  { start_row: integer, end_row: integer, text: string } | nil
---@field diag_ns    integer          Namespace for forwarded diagnostics

local _state = {} ---@type table<integer, TemplateState>  keyed by src_buf

local SUPPORTED_FT = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
}

-- ── Treesitter helpers ────────────────────────────────────────────────────────

--- Find the innermost template_string ancestor of the node at (row, col).
--- Returns (node, root_text) or nil.
---@param bufnr integer
---@param row   integer  0-indexed
---@param col   integer  0-indexed
local function find_template_string(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if not ok or not node then
    return nil
  end

  local curr = node
  while curr do
    if curr:type() == "template_string" then
      return curr
    end
    curr = curr:parent()
  end
  return nil
end

--- Get the *raw* template text for a template_string node, stripping the
--- surrounding backticks and any template substitutions (${...}) replaced
--- with whitespace so offsets stay the same.
---@param bufnr integer
---@param node  TSNode
local function template_to_html(bufnr, node)
  local lines = vim.api.nvim_buf_get_lines(bufnr, node:start(), node:end_(), false)
  if #lines == 0 then
    return nil, nil, nil
  end

  local text = table.concat(lines, "\n")
  local start_row = node:start()

  -- Strip opening and closing backticks at boundaries.
  -- The first char of the first line is a backtick — replace with space.
  text = text:gsub("^`", " ")
  -- Trailing backtick (and possible semi-colon) at end.
  text = text:gsub("`%s*;?%s*$", "")

  -- Replace ${...} expressions with equivalent-length whitespace so that:
  --   a) column offsets in the virtual buffer match those in the source.
  --   b) the HTML parser sees valid-ish markup (gaps are treated as text).
  --
  -- We use a simple depth-tracking replacer that handles nested braces.
  local result = {}
  local i = 1
  while i <= #text do
    if text:sub(i, i + 1) == "${" then
      local depth = 1
      result[#result + 1] = "  " -- replace ${ with two spaces
      i = i + 2
      while i <= #text and depth > 0 do
        local ch = text:sub(i, i)
        if ch == "{" then
          depth = depth + 1
        elseif ch == "}" then
          depth = depth - 1
        end
        if depth > 0 then
          -- Preserve newlines; replace other chars with spaces.
          result[#result + 1] = (ch == "\n") and "\n" or " "
        else
          result[#result + 1] = " " -- replace closing }
        end
        i = i + 1
      end
    else
      result[#result + 1] = text:sub(i, i)
      i = i + 1
    end
  end

  local html = table.concat(result)
  return html, start_row, node:end_()
end

--- Return true if text looks like it contains HTML markup.
---@param text string
local function contains_html(text)
  return text:find("<%s*[%a!/][^>]*>") ~= nil
end

-- ── Virtual buffer management ─────────────────────────────────────────────────

--- Return the stem of a file path (basename without extension), used to build
--- the virtual buffer name.
local function buf_stem(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and name or ("[buf " .. bufnr .. "]")
end

--- Create (or reset) the virtual HTML buffer for a source buffer.
---@param src_buf integer
---@return integer html_buf
local function get_or_create_html_buf(src_buf)
  local st = _state[src_buf]
  if st and vim.api.nvim_buf_is_valid(st.html_buf) then
    return st.html_buf
  end

  local vname = buf_stem(src_buf) .. ".__html_template__"
  -- Reuse an existing scratch buffer with the same name if one exists.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b) == vname then
      if not st then
        st = {}
        _state[src_buf] = st
      end
      st.html_buf = b
      return b
    end
  end

  local html_buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
  vim.api.nvim_buf_set_name(html_buf, vname)
  vim.bo[html_buf].filetype = "html"
  vim.bo[html_buf].bufhidden = "hide"
  vim.bo[html_buf].swapfile = false
  vim.bo[html_buf].buflisted = false

  if not st then
    st = { diag_ns = vim.api.nvim_create_namespace("tmpl_diag_" .. src_buf) }
    _state[src_buf] = st
  end
  st.html_buf = html_buf
  st.src_buf = src_buf

  return html_buf
end

-- ── LSP attachment ────────────────────────────────────────────────────────────

--- Start or find the html LSP client and attach it to the virtual buffer.
---@param html_buf integer
---@param src_buf  integer  used to inherit root_dir
---@return integer|nil client_id
local function ensure_html_lsp(html_buf, src_buf)
  local st = _state[src_buf]
  if st and st.client_id then
    local c = vim.lsp.get_client_by_id(st.client_id)
    if c then
      -- Attach if not already (use non-deprecated buf_is_attached check).
      if not vim.lsp.buf_is_attached(html_buf, st.client_id) then
        vim.lsp.buf_attach_client(html_buf, st.client_id)
      end
      return st.client_id
    end
  end

  -- Build an html config derived from the registered one.
  local base_cfg = vim.tbl_deep_extend("force", {}, vim.lsp.config["html"] or {})
  -- Inherit root_dir from source buffer or fall back to cwd.
  local src_name = vim.api.nvim_buf_get_name(src_buf)
  local root = vim.fs.root(src_name, { "package.json", ".git" }) or vim.fn.getcwd()

  -- Reuse an existing html_template client if one is already running.
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.name == "html_template" then
      vim.lsp.buf_attach_client(html_buf, client.id)
      if st then
        st.client_id = client.id
      end
      return client.id
    end
  end

  local cfg = vim.tbl_deep_extend("force", base_cfg, {
    name = "html_template",
    filetypes = { "html" },
    root_dir = root,
  })
  -- Remove keys that are invalid for vim.lsp.start config in 0.12
  cfg.single_file_support = nil

  local client_id = vim.lsp.start(cfg, { bufnr = html_buf })
  if client_id and st then
    st.client_id = client_id
  end
  return client_id
end

-- ── Diagnostic forwarding ─────────────────────────────────────────────────────

--- Forward diagnostics from the virtual HTML buffer back to the source JS
--- buffer, offsetting line numbers by the template start row.
---@param src_buf  integer
---@param html_buf integer
---@param start_row integer  0-indexed line where the template string starts
local function forward_diagnostics(src_buf, html_buf, start_row)
  if not vim.api.nvim_buf_is_valid(src_buf) then
    return
  end
  local st = _state[src_buf]
  if not st then
    return
  end

  local html_diags = vim.diagnostic.get(html_buf)
  local forwarded = {}
  for _, d in ipairs(html_diags) do
    forwarded[#forwarded + 1] = {
      lnum = d.lnum + start_row,
      end_lnum = d.end_lnum + start_row,
      col = d.col,
      end_col = d.end_col,
      message = "[html] " .. d.message,
      severity = d.severity,
      source = "html-template",
    }
  end

  vim.diagnostic.set(st.diag_ns, src_buf, forwarded)
end

-- ── Sync logic ────────────────────────────────────────────────────────────────

--- Synchronise the virtual HTML buffer with the template string under cursor
--- (or anywhere in the source buffer on TextChanged events).
---@param src_buf integer
---@param row     integer  0-indexed cursor row  (pass -1 to skip position check)
---@param col     integer  0-indexed cursor col
function M.sync_now(src_buf, row, col)
  if not vim.api.nvim_buf_is_valid(src_buf) then
    return
  end

  -- Make sure treesitter is running.
  local parser_ok, parser = pcall(vim.treesitter.get_parser, src_buf)
  if not parser_ok or not parser then
    return
  end
  parser:parse(true)

  local tmpl_node = find_template_string(src_buf, row, col)
  if not tmpl_node then
    -- Cursor not inside a template string. Clear any forwarded diagnostics and
    -- don't tear down the virtual buffer (it may be needed when moving back in).
    local st = _state[src_buf]
    if st and st.diag_ns then
      vim.diagnostic.reset(st.diag_ns, src_buf)
    end
    return
  end

  local html_text, start_row, _end_row = template_to_html(src_buf, tmpl_node)
  if not html_text or not contains_html(html_text) then
    return
  end

  local html_buf = get_or_create_html_buf(src_buf)
  local st = _state[src_buf]
  st.last_tmpl = { start_row = start_row, end_row = _end_row, text = html_text }

  -- Only update the virtual buffer if the content changed.
  local current_lines = vim.api.nvim_buf_get_lines(html_buf, 0, -1, false)
  local new_lines = vim.split(html_text, "\n", { plain = true })
  if table.concat(current_lines, "\n") ~= html_text then
    vim.api.nvim_buf_set_lines(html_buf, 0, -1, false, new_lines)
  end

  -- Attach the HTML language server.
  ensure_html_lsp(html_buf, src_buf)

  -- Schedule diagnostic forwarding after a short delay (LSP needs time).
  vim.defer_fn(function()
    if st.last_tmpl then
      forward_diagnostics(src_buf, html_buf, st.last_tmpl.start_row)
    end
  end, 300)
end

-- ── Cursor position to virtual buffer position ────────────────────────────────

--- Translate a source buffer (row, col) to virtual HTML buffer position.
--- Returns (html_row, col) or nil if outside any template.
---@param src_buf integer
---@param row     integer  0-indexed
---@param col     integer
function M.src_to_html_pos(src_buf, row, col)
  local st = _state[src_buf]
  if not st or not st.last_tmpl then
    return nil
  end
  local offset = st.last_tmpl.start_row
  if row < offset then
    return nil
  end
  return row - offset, col
end

-- ── Public getters ────────────────────────────────────────────────────────────

--- Return the virtual HTML bufnr for a source buffer, or nil.
---@param src_buf? integer  defaults to current buffer
function M.get_html_buf(src_buf)
  src_buf = src_buf or vim.api.nvim_get_current_buf()
  local st = _state[src_buf]
  return st and vim.api.nvim_buf_is_valid(st.html_buf) and st.html_buf or nil
end

--- Return the html LSP client attached to the virtual buffer, or nil.
---@param src_buf? integer
function M.get_html_client(src_buf)
  src_buf = src_buf or vim.api.nvim_get_current_buf()
  local st = _state[src_buf]
  if not st or not st.client_id then
    return nil
  end
  return vim.lsp.get_client_by_id(st.client_id)
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

local _setup_done = false

function M.setup()
  if _setup_done then
    return
  end
  _setup_done = true

  local group = vim.api.nvim_create_augroup("custom_template_html", { clear = true })

  -- On entering or moving in a supported JS/TS buffer, sync the template.
  local function on_cursor_moved(bufnr)
    if not SUPPORTED_FT[vim.bo[bufnr].filetype] then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    -- nvim_win_get_cursor returns 1-indexed row; treesitter uses 0-indexed.
    M.sync_now(bufnr, pos[1] - 1, pos[2])
  end

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      on_cursor_moved(ev.buf)
    end,
    desc = "template: sync HTML virtual buffer on cursor move",
  })

  -- On text change, re-sync if we're inside a template.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      local bufnr = ev.buf
      if not SUPPORTED_FT[vim.bo[bufnr].filetype] then
        return
      end
      local st = _state[bufnr]
      -- Only re-sync if we already have a virtual buffer open.
      if not st or not vim.api.nvim_buf_is_valid(st.html_buf or 0) then
        return
      end
      local pos = vim.api.nvim_win_get_cursor(0)
      M.sync_now(bufnr, pos[1] - 1, pos[2])
    end,
    desc = "template: keep HTML virtual buffer in sync on edit",
  })

  -- Clean up state when a source buffer is deleted.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      local st = _state[ev.buf]
      if not st then
        return
      end
      if st.html_buf and vim.api.nvim_buf_is_valid(st.html_buf) then
        pcall(vim.api.nvim_buf_delete, st.html_buf, { force = true })
      end
      _state[ev.buf] = nil
    end,
    desc = "template: clean up virtual HTML buffer",
  })

  -- Register a command to reveal the virtual buffer for debugging.
  vim.api.nvim_create_user_command("TemplateHtmlBuf", function()
    local html_buf = M.get_html_buf()
    if not html_buf then
      vim.notify("No HTML template buffer for this file", vim.log.levels.WARN, { title = "Template" })
      return
    end
    -- Open in a split.
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, html_buf)
  end, { desc = "Reveal the virtual HTML template buffer" })

  vim.api.nvim_create_user_command("TemplateStatus", function()
    local src_buf = vim.api.nvim_get_current_buf()
    local st = _state[src_buf]
    if not st then
      vim.notify("No template state for this buffer", vim.log.levels.INFO, { title = "Template" })
      return
    end
    local client = M.get_html_client(src_buf)
    local lines = {
      "Template HTML support",
      "  src_buf  : " .. src_buf,
      "  html_buf : " .. (st.html_buf or "none"),
      "  client   : " .. (client and client.name or "none"),
      "  tmpl rows: "
        .. (st.last_tmpl and (st.last_tmpl.start_row + 1 .. " – " .. st.last_tmpl.end_row + 1) or "none"),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Template" })
  end, { desc = "Show template HTML support status" })
end

return M
