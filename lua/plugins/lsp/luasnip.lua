return {
  'l3mon4d3/luasnip',
  version = 'v2.*',

  build = (function()
    -- Regex support for snippets
    if vim.fn.executable 'make' == 0 then
      return
    end
    return 'make install_jsregexp'
  end)(),

  dependencies = {
    {
      'rafamadriz/friendly-snippets',
      config = function()
        -- Optional: enable if you want auto-loading
        -- require('luasnip.loaders.from_vscode').lazy_load()
      end,
    },
  },

  opts = {
    history = true,
    updateevents = 'TextChanged,TextChangedI',
  },

  config = function(_, opts)
    local luasnip = require 'luasnip'

    luasnip.config.set_config(opts)

    -- VS Code snippets
    require('luasnip.loaders.from_vscode').lazy_load {
      exclude = vim.g.vscode_snippets_exclude or {},
    }
    require('luasnip.loaders.from_vscode').lazy_load {
      paths = vim.g.vscode_snippets_path or '',
    }

    -- SnipMate snippets
    require('luasnip.loaders.from_snipmate').load()
    require('luasnip.loaders.from_snipmate').lazy_load {
      paths = vim.g.snipmate_snippets_path or '',
    }

    -- Lua snippets
    require('luasnip.loaders.from_lua').load()
    require('luasnip.loaders.from_lua').lazy_load {
      paths = vim.g.lua_snippets_path or '',
    }

    -- Fix for luasnip issue #258
    vim.api.nvim_create_autocmd('InsertLeave', {
      callback = function()
        local session = luasnip.session
        local bufnr = vim.api.nvim_get_current_buf()

        if session.current_nodes[bufnr] and not session.jump_active then
          luasnip.unlink_current()
        end
      end,
    })
  end,
}
