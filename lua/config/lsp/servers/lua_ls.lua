return {
  settings = {
    Lua = {

      completion = {
        callSnippet = 'Replace',
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
    },
  },
}
