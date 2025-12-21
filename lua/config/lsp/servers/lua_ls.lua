return {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      completion = {
        autoRequire = true,
        callSnippet = 'Both',
        displayContext = 5,
        enable = true,
        keywordSnippet = 'Both',
        portfix = '.',
        showWord = 'Enable',
      },

      workspace = {
        library = {
          vim.fn.expand '$VIMRUNTIME/lua',
          vim.fn.stdpath 'config' .. '/lua',
        },
      },
      hint = {
        enable = true,
        arrayIndex = 'Auto',
        await = true,
        paramName = 'All',
        paramType = true,
        semicolon = 'All',
        setType = false,
      },
      telemetry = {
        enable = false,
      },
      diagnostics = {
        globals = { 'vim', 'scroll' },
      },
      doc = {
        privateName = { '^_' },
      },
    },
  },
}
