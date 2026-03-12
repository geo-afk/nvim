return {
  'L3MON4D3/LuaSnip',
  version = 'v2.*', -- follows latest major release
  build = (function()
    if vim.fn.executable 'make' == 0 then
      return
    end
    return 'make install_jsregexp'
  end)(),
  dependencies = {
    'rafamadriz/friendly-snippets',
  },
  opts = {
    history = true,
    update_events = 'TextChanged,TextChangedI',
    delete_check_events = 'TextChanged', -- auto-clean deleted snippet text
    region_check_events = 'CursorMoved', -- exit snippet when cursor leaves region
    -- enable_autosnippets = true,                -- uncomment if using autosnippets
    -- ext_opts = { ... },                        -- customize virt-text, etc.
  },
  config = function(_, opts)
    local luasnip = require 'luasnip'

    -- Apply config
    luasnip.config.setup(opts)

    -- Load friendly-snippets (VSCode style) lazily
    local vscode_ok = pcall(require('luasnip.loaders.from_vscode').lazy_load, {
      exclude = vim.g.vscode_snippets_exclude or {},
    })
    if not vscode_ok then
      vim.notify('LuaSnip: failed to load VSCode snippets', vim.log.levels.WARN)
    end

    -- Custom VSCode paths if set
    if vim.g.vscode_snippets_path and vim.g.vscode_snippets_path ~= '' then
      pcall(require('luasnip.loaders.from_vscode').lazy_load, {
        paths = vim.g.vscode_snippets_path,
      })
    end

    -- SnipMate (prefer lazy)
    pcall(require('luasnip.loaders.from_snipmate').lazy_load, {
      paths = vim.g.snipmate_snippets_path or '',
    })

    -- Lua snippets
    pcall(require('luasnip.loaders.from_lua').lazy_load, {
      paths = vim.g.lua_snippets_path or '',
    })

    -- Optional: load all Lua snippets eagerly if small set
    -- pcall(require('luasnip.loaders.from_lua').load)

    -- Clean up stale sessions on InsertLeave (still useful)
    vim.api.nvim_create_autocmd('InsertLeave', {
      callback = function()
        local session = luasnip.session
        local bufnr = vim.api.nvim_get_current_buf()
        if session.current_nodes[bufnr] and not session.jump_active then
          luasnip.unlink_current()
        end
      end,
      desc = 'LuaSnip: unlink current snippet on InsertLeave',
    })
  end,
}
