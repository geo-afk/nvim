--- lsp-keymapper/capabilities.lua
--- Defines the canonical mapping from LSP server_capability keys to
--- vim.lsp.buf handlers, display labels, and suggested default keys.

local M = {}
local code_action = require("custom.code_action")

--- @class LspCapabilityDef
--- @field label        string   Human-readable name shown in the UI
--- @field description  string   One-line description of what the action does
--- @field handler      string   Lua expression (as string) for the action
--- @field fn           function The actual callable action
--- @field modes        string[] Default modes for the keymap (e.g. { "n" })
--- @field suggested    string   Opinionated suggested key for first-time users

--- Full registry of supported LSP capability → action definitions.
--- Keys match fields inside `client.server_capabilities`.
---
--- @type table<string, LspCapabilityDef>
M.registry = {
  hoverProvider = {
    label = "Hover",
    description = "Show documentation / type info for the symbol under the cursor",
    handler = "vim.lsp.buf.hover()",
    fn = vim.lsp.buf.hover,
    modes = { "n" },
    suggested = "K",
  },
  definitionProvider = {
    label = "Go to Definition",
    description = "Jump to the definition of the symbol under the cursor",
    handler = "vim.lsp.buf.definition()",
    fn = vim.lsp.buf.definition,
    modes = { "n" },
    suggested = "gd",
  },
  declarationProvider = {
    label = "Go to Declaration",
    description = "Jump to the declaration of the symbol under the cursor",
    handler = "vim.lsp.buf.declaration()",
    fn = vim.lsp.buf.declaration,
    modes = { "n" },
    suggested = "gD",
  },
  typeDefinitionProvider = {
    label = "Go to Type Definition",
    description = "Jump to the type definition of the symbol under the cursor",
    handler = "vim.lsp.buf.type_definition()",
    fn = vim.lsp.buf.type_definition,
    modes = { "n" },
    suggested = "gy",
  },
  implementationProvider = {
    label = "Go to Implementation",
    description = "List / jump to implementations of the symbol under the cursor",
    handler = "vim.lsp.buf.implementation()",
    fn = vim.lsp.buf.implementation,
    modes = { "n" },
    suggested = "gi",
  },
  referencesProvider = {
    label = "Find References",
    description = "List all references to the symbol under the cursor",
    handler = "vim.lsp.buf.references()",
    fn = function()
      vim.lsp.buf.references()
    end,
    modes = { "n" },
    suggested = "gr",
  },
  renameProvider = {
    label = "Rename Symbol",
    description = "Rename the symbol under the cursor across the project",
    handler = "vim.lsp.buf.rename()",
    fn = vim.lsp.buf.rename,
    modes = { "n" },
    suggested = "<leader>rn",
  },
  codeActionProvider = {
    label = "Code Action",
    description = "Trigger code actions (quick-fixes, refactors) at the cursor",
    handler = 'require("custom.code_action_menu").open()',
    fn = function()
      code_action.open()
    end,
    modes = { "n", "v" },
    suggested = "<leader>ca",
  },
  documentFormattingProvider = {
    label = "Format Document",
    description = "Format the entire current buffer",
    handler = "vim.lsp.buf.format({ async = true })",
    fn = function()
      vim.lsp.buf.format({ async = true })
    end,
    modes = { "n" },
    suggested = "<leader>f",
  },
  documentRangeFormattingProvider = {
    label = "Format Range",
    description = "Format the selected range",
    handler = "vim.lsp.buf.format({ async = true })",
    fn = function()
      vim.lsp.buf.format({ async = true })
    end,
    modes = { "v" },
    suggested = "<leader>f",
  },
  documentSymbolProvider = {
    label = "Document Symbols",
    description = "List all symbols (functions, classes, …) in the current file",
    handler = "vim.lsp.buf.document_symbol()",
    fn = vim.lsp.buf.document_symbol,
    modes = { "n" },
    suggested = "<leader>ds",
  },
  workspaceSymbolProvider = {
    label = "Workspace Symbols",
    description = "Search symbols across the entire workspace",
    handler = "vim.lsp.buf.workspace_symbol()",
    fn = function()
      vim.lsp.buf.workspace_symbol()
    end,
    modes = { "n" },
    suggested = "<leader>ws",
  },
  signatureHelpProvider = {
    label = "Signature Help",
    description = "Show function / method signature hints",
    handler = "vim.lsp.buf.signature_help()",
    fn = vim.lsp.buf.signature_help,
    modes = { "n", "i" },
    suggested = "<C-k>",
  },
  documentHighlightProvider = {
    label = "Highlight References",
    description = "Highlight all references to the symbol under the cursor",
    handler = "vim.lsp.buf.document_highlight()",
    fn = vim.lsp.buf.document_highlight,
    modes = { "n" },
    suggested = "<leader>hl",
  },
  codeLensProvider = {
    label = "Run Code Lens",
    description = "Execute the code lens action on the current line",
    handler = "vim.lsp.codelens.run()",
    fn = vim.lsp.codelens.run,
    modes = { "n" },
    suggested = "<leader>cl",
  },
  callHierarchyProvider = {
    label = "Incoming Calls",
    description = "Show the call hierarchy (who calls this function)",
    handler = "vim.lsp.buf.incoming_calls()",
    fn = vim.lsp.buf.incoming_calls,
    modes = { "n" },
    suggested = "<leader>ci",
  },
  inlayHintProvider = {
    label = "Toggle Inlay Hints",
    description = "Toggle LSP inlay hints in the current buffer",
    handler = "vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())",
    fn = function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end,
    modes = { "n" },
    suggested = "<leader>ih",
  },
  diagnosticProvider = {
    label = "Diagnostics",
    description = "Open the diagnostics float for the current line",
    handler = "vim.diagnostic.open_float()",
    fn = vim.diagnostic.open_float,
    modes = { "n" },
    suggested = "<leader>e",
  },
  selectionRangeProvider = {
    label = "Expand Selection",
    description = "Expand the visual selection using semantic ranges",
    handler = "vim.lsp.buf.document_highlight()",
    fn = vim.lsp.buf.document_highlight,
    modes = { "n", "v" },
    suggested = "<leader>sr",
  },
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Dynamic discovery
-- ──────────────────────────────────────────────────────────────────────────────

--- Keys that exist in server_capabilities but are internal Neovim/LSP plumbing
--- and should never be surfaced as user-mappable capabilities.
local SKIP_KEYS = {
  -- Neovim client-side flags (not server caps)
  positionEncoding = true,
  -- These are container tables we recurse into manually
  workspace = true,
  -- Completion is server-driven (triggered by the engine, not user keymaps)
  completionProvider = true,
  -- Text sync is internal protocol glue
  textDocumentSync = true,
}

--- Pattern-based heuristic: map unknown capability key substrings to the most
--- sensible vim.lsp.buf handler.  Checked in order; first match wins.
---
--- @type { pattern: string, fn: function, modes: string[], description: string }[]
local HEURISTIC_HANDLERS = {
  {
    pattern = "definition",
    fn = vim.lsp.buf.definition,
    modes = { "n" },
    description = "Go to definition (auto-detected)",
  },
  {
    pattern = "declaration",
    fn = vim.lsp.buf.declaration,
    modes = { "n" },
    description = "Go to declaration (auto-detected)",
  },
  {
    pattern = "implementation",
    fn = vim.lsp.buf.implementation,
    modes = { "n" },
    description = "Go to implementation (auto-detected)",
  },
  {
    pattern = "typeDefinition",
    fn = vim.lsp.buf.type_definition,
    modes = { "n" },
    description = "Go to type definition (auto-detected)",
  },
  {
    pattern = "reference",
    fn = function()
      vim.lsp.buf.references()
    end,
    modes = { "n" },
    description = "Find references (auto-detected)",
  },
  { pattern = "hover", fn = vim.lsp.buf.hover, modes = { "n" }, description = "Show hover info (auto-detected)" },
  { pattern = "rename", fn = vim.lsp.buf.rename, modes = { "n" }, description = "Rename symbol (auto-detected)" },
  {
    pattern = "[Aa]ction",
    fn = function()
      code_action.open()
    end,
    modes = { "n", "v" },
    description = "Code action (auto-detected)",
  },
  {
    pattern = "[Ff]ormat",
    fn = function()
      vim.lsp.buf.format({ async = true })
    end,
    modes = { "n" },
    description = "Format (auto-detected)",
  },
  { pattern = "[Ss]ymbol", fn = vim.lsp.buf.document_symbol, modes = { "n" }, description = "Symbols (auto-detected)" },
  {
    pattern = "[Ss]ignature",
    fn = vim.lsp.buf.signature_help,
    modes = { "n", "i" },
    description = "Signature help (auto-detected)",
  },
  { pattern = "[Ll]ens", fn = vim.lsp.codelens.run, modes = { "n" }, description = "Code lens (auto-detected)" },
  {
    pattern = "[Hh]int",
    fn = function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end,
    modes = { "n" },
    description = "Inlay hints toggle (auto-detected)",
  },
  {
    pattern = "[Dd]iagnostic",
    fn = vim.diagnostic.open_float,
    modes = { "n" },
    description = "Diagnostics float (auto-detected)",
  },
  {
    pattern = "[Cc]all",
    fn = vim.lsp.buf.incoming_calls,
    modes = { "n" },
    description = "Call hierarchy (auto-detected)",
  },
  {
    pattern = "[Hh]ighlight",
    fn = vim.lsp.buf.document_highlight,
    modes = { "n" },
    description = "Highlight references (auto-detected)",
  },
}

--- Convert a camelCase capability key into a human-readable label.
--- e.g. "executeCommandProvider" → "Execute Command Provider"
---
--- @param key string
--- @return string
local function key_to_label(key)
  -- Strip trailing "Provider" for cleanliness
  local s = key:gsub("Provider$", "")
  -- Split on camelCase boundaries and title-case each word
  s = s:gsub("(%l)(%u)", "%1 %2")
  s = s:gsub("(%u+)(%u%l)", "%1 %2")
  return s:sub(1, 1):upper() .. s:sub(2)
end

--- Serialise a capability value to a compact human-readable string for display.
--- All output is guaranteed to be free of newline characters so it is safe
--- to pass directly to nvim_buf_set_lines.
---
--- @param val any
--- @return string
local function summarise_value(val)
  --- Strip every newline / carriage-return from a string.
  local function clean(s)
    return tostring(s):gsub("[\n\r]", " ")
  end

  if type(val) == "boolean" then
    return val and "true" or "false"
  end

  if type(val) ~= "table" then
    return clean(val)
  end

  -- For array-like tables (e.g. executeCommandProvider.commands) show a
  -- count and the first element only so the line stays short.
  local is_array = (#val > 0)
  if is_array then
    local first = clean(val[1] or "")
    if #first > 30 then
      first = first:sub(1, 27) .. "..."
    end
    return string.format("[%d items, first: %s]", #val, first)
  end

  -- For map-like tables collect up to 4 key=value pairs.
  local parts = {}
  local count = 0
  for k, v in pairs(val) do
    if count >= 4 then
      table.insert(parts, "...")
      break
    end
    if type(v) == "table" then
      table.insert(parts, clean(k) .. "={...}")
    else
      local vs = clean(v)
      if #vs > 20 then
        vs = vs:sub(1, 17) .. "..."
      end
      table.insert(parts, clean(k) .. "=" .. vs)
    end
    count = count + 1
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

--- Try to find a heuristic handler for an unknown capability key.
---
--- @param cap_key string
--- @return function|nil, string[], string  fn, modes, description
local function heuristic_for(cap_key)
  for _, h in ipairs(HEURISTIC_HANDLERS) do
    if cap_key:find(h.pattern) then
      return h.fn, h.modes, h.description
    end
  end
  return nil, { "n" }, "No automatic handler available"
end

--- @class DiscoveredCapability
--- @field cap_key     string   The raw key from server_capabilities
--- @field label       string   Auto-generated human-readable label
--- @field description string   Short description / summary of the raw value
--- @field raw_value   any      The exact value reported by the server
--- @field fn          function|nil  Best-effort handler (may be nil)
--- @field modes       string[]
--- @field suggested   string
--- @field is_discovered boolean  Always true; distinguishes from registry entries

--- Scan `server_capabilities` for keys not covered by the registry and return
--- structured `DiscoveredCapability` entries.
---
--- Handles one level of nesting: the `workspace` sub-table is walked and its
--- children are exposed as "workspace.<key>" entries.
---
--- @param client vim.lsp.Client
--- @return DiscoveredCapability[]
function M.discover_unknown(client)
  local sc = client.server_capabilities or {}
  local found = {}

  local function process(key, val, prefix)
    -- Skip falsy values — server is explicitly saying "not supported"
    if val == nil or val == false then
      return
    end
    -- Skip internal plumbing keys
    if SKIP_KEYS[key] then
      return
    end
    -- Skip anything already in the registry (those are shown in the main list)
    if M.registry[key] then
      return
    end

    local display_key = prefix and (prefix .. "." .. key) or key
    local fn, modes, auto_desc = heuristic_for(key)
    local value_summary = summarise_value(val)

    table.insert(found, {
      cap_key = display_key,
      label = key_to_label(key),
      description = auto_desc,
      raw_value = val,
      value_summary = value_summary,
      fn = fn,
      modes = modes,
      suggested = "",
      is_discovered = true,
    })
  end

  -- Top-level capabilities
  for key, val in pairs(sc) do
    process(key, val, nil)
  end

  -- One level of nesting for the `workspace` sub-table
  if type(sc.workspace) == "table" then
    for key, val in pairs(sc.workspace) do
      process(key, val, "workspace")
    end
  end

  -- Sort alphabetically by label for a stable, readable order
  table.sort(found, function(a, b)
    return a.label < b.label
  end)

  return found
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Registry queries
-- ──────────────────────────────────────────────────────────────────────────────

--- Returns a list of capability keys that are active on a given client.
--- A capability is considered "active" when its value is not false/nil,
--- accounting for both boolean and table-style capability objects.
---
--- @param client vim.lsp.Client
--- @return string[] active_keys
function M.get_active(client)
  local active = {}
  local sc = client.server_capabilities or {}

  for cap_key, _ in pairs(M.registry) do
    local val = sc[cap_key]
    if val ~= nil and val ~= false then
      table.insert(active, cap_key)
    end
  end

  table.sort(active, function(a, b)
    return M.registry[a].label < M.registry[b].label
  end)

  return active
end

return M
