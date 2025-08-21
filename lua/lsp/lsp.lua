local lsp_util = require 'constants.lsp_util'

return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    { 'mason-org/mason.nvim', opts = {} },
    'mason-org/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'saghen/blink.cmp',
  },
  opts = {
    inlay_hints = { enabled = true },
  },
  config = function()
    -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
    -- and elegantly composed help section, `:help lsp-vs-treesitter`

    -- Diagnostic Config
    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config(lsp_util.diagnostic)
    local lsp_config = require 'config.lsp'

    require('mason-tool-installer').setup { ensure_installed = lsp_util.mason_tool_install }
    require('mason-lspconfig').setup {
      ensure_installed = lsp_util.mason_lsp,
      automatic_installation = false,
    }
    lsp_config.setup_lsps()
    lsp_config.setup()
  end,
}
