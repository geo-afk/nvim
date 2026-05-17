-- =============================================================================
--  plugins/snippets.lua  ·  LuaSnip + friendly-snippets
--
--  Includes the user's custom Go error-handling snippet that uses Treesitter
--  to detect function return types and generate correct return values.
-- =============================================================================

vim.pack.add({
  {
    src = "https://github.com/L3MON4D3/LuaSnip",
    build = (function()
      if vim.fn.executable("make") == 1 then
        return "make install_jsregexp"
      end
    end)(),
  },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
})

local ok, luasnip = pcall(require, "luasnip")
if not ok then
  return
end

-- ── Core config ───────────────────────────────────────────────────────────────
luasnip.config.setup({
  history = true,
  update_events = "TextChanged,TextChangedI",
  delete_check_events = "TextChanged",
  region_check_events = "CursorMoved",
})

-- ── Load snippet collections ──────────────────────────────────────────────────
pcall(require("luasnip.loaders.from_vscode").load, {
  exclude = vim.g.vscode_snippets_exclude or {},
})

if vim.g.vscode_snippets_path and vim.g.vscode_snippets_path ~= "" then
  pcall(require("luasnip.loaders.from_vscode").load, {
    paths = vim.g.vscode_snippets_path,
  })
end

pcall(require("luasnip.loaders.from_snipmate").load, {
  paths = vim.g.snipmate_snippets_path or "",
})

pcall(require("luasnip.loaders.from_lua").load, {
  paths = vim.g.lua_snippets_path or "",
})

-- ── Unlink snippet session on InsertLeave ────────────────────────────────────
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    local session = luasnip.session
    local bufnr = vim.api.nvim_get_current_buf()
    if session.current_nodes[bufnr] and not session.jump_active then
      luasnip.unlink_current()
    end
  end,
  desc = "LuaSnip: unlink current snippet on InsertLeave",
})

-- ── Custom Go error-handling snippet (Treesitter-aware) ──────────────────────
local ls = luasnip
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local d = ls.dynamic_node
local l = ls.choice_node
local sn = ls.snippet_node
local snfn = ls.sn
local fmt = require("luasnip.extras.fmt").fmt
local get_node_text = vim.treesitter.get_node_text

vim.treesitter.query.set(
  "go",
  "LuaSnip_Result",
  [[
  [
    (method_declaration   result: (_) @id)
    (function_declaration result: (_) @id)
    (func_literal         result: (_) @id)
  ]
]]
)

local function is_nilable(text)
  return text:find("%*") or text:find("%[%]") or text:find("^map") or text:find("^chan")
end

local function transform(text, info)
  local int_types = {
    int = true,
    int8 = true,
    int16 = true,
    int32 = true,
    int64 = true,
    uint = true,
    uint8 = true,
    uint16 = true,
    uint32 = true,
    uint64 = true,
  }
  if int_types[text] then
    return t("0")
  end
  if text == "float32" or text == "float64" then
    return t("0.0")
  end
  if text == "bool" then
    return t("false")
  end
  if text == "string" then
    return t('""')
  end
  if text == "error" then
    if info then
      info.index = info.index + 1
      return l(info.index, {
        sn(nil, i(1, info.err_name)),
        sn(nil, fmt('fmt.Errorf("{}: %v", {})', { i(1), i(2, info.err_name) })),
        sn(nil, fmt('fmt.Errorf("{}: %w", {})', { i(1), i(2, info.err_name) })),
      })
    end
    return t("err")
  end
  if is_nilable(text) then
    return t("nil")
  end
  return t(text)
end

local handlers = {
  parameter_list = function(node, info)
    local result, count = {}, node:named_child_count()
    for idx = 0, count - 1 do
      table.insert(result, transform(get_node_text(node:named_child(idx), 0), info))
      if idx ~= count - 1 then
        table.insert(result, t(", "))
      end
    end
    return result
  end,
  type_identifier = function(node, info)
    return { transform(get_node_text(node, 0), info) }
  end,
}

local function go_result_type(info)
  local query = vim.treesitter.query.get("go", "LuaSnip_Result")
  local parser = vim.treesitter.get_parser(0, "go")
  if not parser then
    return { t("") }
  end

  local root = parser:parse(true)[1]:root()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  for _, match in query:iter_matches(root, 0, row, row + 1, { all = true }) do
    for _, nodes in ipairs(match) do
      for _, node in ipairs(nodes) do
        if handlers[node:type()] then
          return handlers[node:type()](node, info)
        end
      end
    end
  end
  return { t("") }
end

ls.add_snippets("go", {
  s("err", {
    t("if "),
    i(1, "err"),
    t({ " != nil {", "\treturn " }),
    d(2, function(args)
      return snfn(nil, go_result_type({ index = 0, err_name = args[1][1] }))
    end, { 1 }),
    t({ "", "}" }),
    i(0),
  }),
})
