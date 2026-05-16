local M = {}

-- Capture the built-in hover handler at require-time, before setup() overrides it.
-- This ensures fallback always reaches Neovim's real renderer regardless of load order.
local _builtin_hover = vim.lsp.handlers["textDocument/hover"]

-- ── Constants ─────────────────────────────────────────────────────────────────
local SWAG_TAGS = {
  "@Summary",
  "@Description",
  "@ID",
  "@Tags",
  "@Accept",
  "@Produce",
  "@Param",
  "@Success",
  "@Failure",
  "@response",
  "@Header",
  "@Router",
  "@Security",
  "@deprecated",
  "@host",
  "@BasePath",
  "@version",
  "@title",
}

-- LSP Symbol Kinds relevant for Go type resolution.
local KIND = {
  Interface = 11,
  Struct = 23, -- not TypeParameter (26); Struct is what gopls reports for Go types
}

-- ── Parsing ───────────────────────────────────────────────────────────────────

---Split concatenated Swag tags back into structured sections.
---gopls may strip newlines from doc comments; this heuristic re-separates them.
---@param text string
---@return table
local function parse_swag_text(text)
  local sections = { params = {}, responses = {}, others = {} }

  local code_block_end = text:find("```\n\n---")
  if code_block_end then
    sections.header_raw = text:sub(1, code_block_end + 3)
    text = text:sub(code_block_end + 7):gsub("^[%s%-]*", "")
  end

  for _, tag in ipairs(SWAG_TAGS) do
    text = text:gsub("(%s)(" .. tag .. ")", "\n%2")
    text = text:gsub("([%w%d\"'])(" .. tag .. ")", "%1\n%2")
  end

  for _, line in ipairs(vim.split(text, "\n", { trimempty = true })) do
    line = vim.trim(line)
    if line:match("^@Summary") then
      sections.summary = line:gsub("^@Summary%s+", "")
    elseif line:match("^@Description") then
      sections.description = line:gsub("^@Description%s+", "")
    elseif line:match("^@Param") then
      sections.params[#sections.params + 1] = line:gsub("^@Param%s+", "")
    elseif line:match("^@Success") or line:match("^@Failure") or line:match("^@response") then
      sections.responses[#sections.responses + 1] = line
    elseif line:match("^@Router") then
      sections.router = line:gsub("^@Router%s+", "")
    elseif line:match("^@") then
      sections.others[#sections.others + 1] = line
    else
      sections.godoc = (sections.godoc or "") .. line .. "\n"
    end
  end

  return sections
end

-- ── Formatting ────────────────────────────────────────────────────────────────

---Render parsed sections as Markdown for the hover window.
---@param sections table
---@return string[]
local function format_swag_markdown(sections)
  local lines = {}

  if sections.header_raw then
    vim.list_extend(lines, vim.split(sections.header_raw, "\n"))
    lines[#lines + 1] = ""
  end

  if sections.summary then
    lines[#lines + 1] = "### " .. sections.summary
    lines[#lines + 1] = ""
  end

  if sections.description and sections.description ~= sections.summary then
    lines[#lines + 1] = sections.description
    lines[#lines + 1] = ""
  end

  if sections.godoc then
    lines[#lines + 1] = vim.trim(sections.godoc)
    lines[#lines + 1] = ""
  end

  if sections.router then
    lines[#lines + 1] = "####  Route"
    lines[#lines + 1] = "`" .. sections.router .. "`"
    lines[#lines + 1] = ""
  end

  if #sections.params > 0 then
    lines[#lines + 1] = "#### 󰇝 Parameters"
    lines[#lines + 1] = "| Name | In | Type | Req | Description |"
    lines[#lines + 1] = "| :--- | :--- | :--- | :--- | :--- |"
    for _, p in ipairs(sections.params) do
      local parts = {}
      for part in p:gmatch("%S+") do
        parts[#parts + 1] = part
      end
      if #parts >= 4 then
        local desc = table.concat(parts, " ", 5):gsub('^"', ""):gsub('"$', "")
        lines[#lines + 1] =
          string.format("| `%s` | %s | `%s` | %s | %s |", parts[1], parts[2], parts[3], parts[4], desc)
      else
        lines[#lines + 1] = "- " .. p
      end
    end
    lines[#lines + 1] = ""
  end

  if #sections.responses > 0 then
    lines[#lines + 1] = "#### 󰅚 Responses"
    lines[#lines + 1] = "| Code | Type | Model | Description |"
    lines[#lines + 1] = "| :--- | :--- | :--- | :--- |"
    for _, r in ipairs(sections.responses) do
      local rest = r:gsub("^@%w+%s+", "")
      local code = rest:match("^(%d+)") or "default"
      local dtype = rest:match("{(.-)}") or "-"
      local after_type = rest:match("}(.*)") or ""
      local model = after_type:match("^%s+(%S+)") or "-"
      local desc = ""
      if model ~= "-" then
        -- Use vim.pesc so model names with pattern-special chars don't break the match.
        desc = after_type:match(vim.pesc(model) .. "%s+(.*)") or ""
      else
        desc = after_type:match("^%s*(.*)") or ""
      end
      desc = desc:gsub('^"', ""):gsub('"$', "")
      lines[#lines + 1] = string.format("| **%s** | `%s` | `%s` | %s |", code, dtype, model, desc)
    end
    lines[#lines + 1] = ""
  end

  if #sections.others > 0 then
    lines[#lines + 1] = "#### 󰋽 Metadata"
    for _, o in ipairs(sections.others) do
      lines[#lines + 1] = "- " .. o
    end
    lines[#lines + 1] = ""
  end

  return lines
end

-- ── Hover Handler ─────────────────────────────────────────────────────────────

function M.handler(err, result, ctx, config)
  if err or not result or not result.contents then
    return _builtin_hover(err, result, ctx, config)
  end

  local value = result.contents.value
  if not value then
    return _builtin_hover(err, result, ctx, config)
  end

  if value:match("@Summary") or value:match("@Param") or value:match("@Router") then
    local sections = parse_swag_text(value)
    local formatted = format_swag_markdown(sections)
    result.contents.value = table.concat(formatted, "\n")
  end

  return _builtin_hover(err, result, ctx, config)
end

-- ── Smart Symbol Resolution ───────────────────────────────────────────────────

---Return the active gopls client for bufnr, or nil.
local function get_gopls(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
end

---Extract the word under the cursor when it sits inside a comment node.
---Returns nil when the cursor is not inside a comment or the word starts with @.
local function symbol_under_cursor()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node or node:type() ~= "comment" then
    return nil
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-indexed

  local head = line:sub(1, col + 1):match("[%w._]+$") or ""
  local tail = line:sub(col + 2):match("^[%w._]+") or ""
  local word = head .. tail

  if word == "" or word:match("^@") then
    return nil
  end
  return word
end

---Find the best Struct or Interface symbol matching word.
local function best_symbol(symbols, word)
  local escaped = vim.pesc(word)
  for _, sym in ipairs(symbols) do
    if sym.kind == KIND.Struct or sym.kind == KIND.Interface then
      if sym.name == word or sym.name:match("%." .. escaped .. "$") then
        return sym
      end
    end
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.smart_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local word = symbol_under_cursor()

  if not word then
    vim.lsp.buf.hover()
    return
  end

  local client = get_gopls(bufnr)
  if not client then
    vim.lsp.buf.hover()
    return
  end

  client:request("workspace/symbol", { query = word }, function(err, symbols)
    if err or not symbols or #symbols == 0 then
      vim.lsp.buf.hover()
      return
    end

    local sym = best_symbol(symbols, word)
    if not sym then
      vim.lsp.buf.hover()
      return
    end

    local params = {
      textDocument = { uri = sym.location.uri },
      position = sym.location.range.start,
    }
    client:request("textDocument/hover", params, function(h_err, h_result)
      if h_err or not h_result then
        vim.lsp.buf.hover()
        return
      end
      M.handler(h_err, h_result, { method = "textDocument/hover", bufnr = bufnr }, {})
    end, bufnr)
  end, bufnr)
end

function M.smart_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local word = symbol_under_cursor()

  if not word then
    vim.lsp.buf.definition()
    return
  end

  local client = get_gopls(bufnr)
  if not client then
    vim.lsp.buf.definition()
    return
  end

  client:request("workspace/symbol", { query = word }, function(err, symbols)
    if err or not symbols or #symbols == 0 then
      vim.lsp.buf.definition()
      return
    end

    local sym = best_symbol(symbols, word)
    if not sym then
      vim.lsp.buf.definition()
      return
    end

    -- Use the client's negotiated encoding, not a hardcoded "utf-16".
    vim.lsp.util.jump_to_location(sym.location, client.offset_encoding)
  end, bufnr)
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

function M.setup()
  -- Override the global hover handler. M.handler falls through to _builtin_hover,
  -- which was captured before this call, so there is no recursion.
  vim.lsp.handlers["textDocument/hover"] = M.handler

  local group = vim.api.nvim_create_augroup("SwagHover", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "go",
    callback = function()
      local opts = { buffer = true, silent = true }
      vim.keymap.set("n", "K", M.smart_hover, vim.tbl_extend("force", opts, { desc = "Swag: Smart Hover" }))
      vim.keymap.set("n", "gd", M.smart_definition, vim.tbl_extend("force", opts, { desc = "Swag: Smart Definition" }))
    end,
  })
end

return M
