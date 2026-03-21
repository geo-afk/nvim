---@type vim.lsp.Config
return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" },
  ---@type lspconfig.settings.lua_ls
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      completion = {
        autoRequire = true,
        callSnippet = "Both",
        displayContext = 5,
        enable = true,
        keywordSnippet = "Both",
        portfix = ".",
        showWord = "Enable",
      },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.stdpath("config") .. "/lua",
        },
      },
      hint = {
        enable = true,
        arrayIndex = "Auto",
        await = true,
        paramName = "All",
        paramType = true,
        semicolon = "All",
        setType = false,
      },
      type = {
        weakNilCheck = true,
      },
      telemetry = {
        enable = false,
      },
      diagnostics = { disable = { "missing-fields" }, globals = { "vim", "scroll" } },
      doc = {
        privateName = { "^_" },
      },
    },
  },
}
