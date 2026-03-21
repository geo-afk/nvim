return {
  "L3MON4D3/LuaSnip",
  version = "v2.*", -- follows latest major release
  build = (function()
    if vim.fn.executable("make") == 0 then
      return
    end
    return "make install_jsregexp"
  end)(),
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  opts = {
    history = true,
    update_events = "TextChanged,TextChangedI",
    delete_check_events = "TextChanged", -- auto-clean deleted snippet text
    region_check_events = "CursorMoved", -- exit snippet when cursor leaves region
    -- enable_autosnippets = true,                -- uncomment if using autosnippets
    -- ext_opts = { ... },                        -- customize virt-text, etc.
  },
  config = function(_, opts)
    local luasnip = require("luasnip")

    -- Apply config
    luasnip.config.setup(opts)

    -- Load friendly-snippets (VSCode style) lazily
    local vscode_ok = pcall(require("luasnip.loaders.from_vscode").lazy_load, {
      exclude = vim.g.vscode_snippets_exclude or {},
    })
    if not vscode_ok then
      vim.notify("LuaSnip: failed to load VSCode snippets", vim.log.levels.WARN)
    end

    -- Custom VSCode paths if set
    if vim.g.vscode_snippets_path and vim.g.vscode_snippets_path ~= "" then
      pcall(require("luasnip.loaders.from_vscode").lazy_load, {
        paths = vim.g.vscode_snippets_path,
      })
    end

    -- SnipMate (prefer lazy)
    pcall(require("luasnip.loaders.from_snipmate").lazy_load, {
      paths = vim.g.snipmate_snippets_path or "",
    })

    -- Lua snippets
    pcall(require("luasnip.loaders.from_lua").lazy_load, {
      paths = vim.g.lua_snippets_path or "",
    })

    -- Optional: load all Lua snippets eagerly if small set
    -- pcall(require('luasnip.loaders.from_lua').load)

    -- Clean up stale sessions on InsertLeave (still useful)
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

    -- ========== CUSTOM GO SNIPPET WITH TREESITTER INTEGRATION ==========
    -- This adds intelligent error handling snippets for Go that automatically
    -- generate appropriate return values based on function signatures

    local ls = luasnip
    local s = ls.snippet
    local t = ls.text_node
    local i = ls.insert_node
    local f = ls.function_node
    local d = ls.dynamic_node
    local c = ls.choice_node
    local sn = ls.snippet_node
    local snippet_from_nodes = ls.sn

    local fmt = require("luasnip.extras.fmt").fmt

    local get_node_text = vim.treesitter.get_node_text

    local function same(index)
      return f(function(args)
        return args[1]
      end, { index })
    end

    -- Treesitter query to find function result positions in Go
    vim.treesitter.query.set(
      "go",
      "LuaSnip_Result",
      [[ [
        (method_declaration result: (_) @id)
        (function_declaration result: (_) @id)
        (func_literal result: (_) @id)
      ] ]]
    )

    local function is_nil_type(text)
      return text:find("%*") or text:find("%[%]") or text:find("^map") or text:find("^chan")
    end

    local transform = function(text, info)
      if
        text == "int"
        or text == "int8"
        or text == "int16"
        or text == "int32"
        or text == "int64"
        or text == "uint"
        or text == "uint8"
        or text == "uint16"
        or text == "uint32"
        or text == "uint64"
      then
        return t("0")
      elseif text == "float32" or text == "float64" then
        return t("0.0")
      elseif text == "bool" then
        return t("false")
      elseif text == "string" then
        return t('""')
      elseif text == "error" then
        if info then
          info.index = info.index + 1

          return c(info.index, {
            sn(nil, i(1, info.err_name)),
            sn(nil, fmt('fmt.Errorf("{}: %v", {})', { i(1), i(2, info.err_name) })),
            sn(nil, fmt('fmt.Errorf("{}: %w", {})', { i(1), i(2, info.err_name) })),
          })
        else
          return t("err")
        end
      elseif is_nil_type(text) then
        return t("nil")
      end

      return t(text)
    end

    local handlers = {
      ["parameter_list"] = function(node, info)
        local result = {}
        local count = node:named_child_count()

        for idx = 0, count - 1 do
          table.insert(result, transform(get_node_text(node:named_child(idx), 0), info))

          if idx ~= count - 1 then
            table.insert(result, t(", "))
          end
        end

        return result
      end,

      ["type_identifier"] = function(node, info)
        local text = get_node_text(node, 0)
        return { transform(text, info) }
      end,
    }

    local function go_result_type(info)
      local query = vim.treesitter.query.get("go", "LuaSnip_Result")
      local parser = vim.treesitter.get_parser(0, "go")

      if not parser then
        return { t("") }
      end

      local root = parser:parse(true)[1]:root()
      local cursor = vim.api.nvim_win_get_cursor(0)

      local start_row = cursor[1] - 1
      local end_row = start_row + 1

      for _, match, metadata in query:iter_matches(root, 0, start_row, end_row, { all = true }) do
        for id, nodes in ipairs(match) do
          for _, node in ipairs(nodes) do
            if handlers[node:type()] then
              return handlers[node:type()](node, info)
            end
          end
        end
      end

      return { t("") }
    end

    local go_ret_vals = function(args)
      return snippet_from_nodes(
        nil,
        go_result_type({
          index = 0,
          err_name = args[1][1],
        })
      )
    end

    -- Register the custom Go error handling snippet
    -- This snippet is only active for Go files
    ls.add_snippets("go", {
      s("err", {
        t("if "),
        i(1, "err"),
        t({ " != nil {", "\treturn " }),
        d(2, go_ret_vals, { 1 }),
        t({ "", "}" }),
        i(0),
      }),
    })

    -- Optional: Add more Go snippets here as needed
    -- Example: Add a snippet for quick error creation
    -- ls.add_snippets("go", {
    --   s("errf", {
    --     t("return fmt.Errorf(\""),
    --     i(1, "error message"),
    --     t("\", "),
    --     i(2, "args"),
    --     t(")"),
    --     i(0),
    --   }),
    -- })
  end,
}
