return {
  'rachartier/tiny-code-action.nvim',
  dependencies = {
    { 'nvim-lua/plenary.nvim' },
    { 'nvim-telescope/telescope.nvim' }, -- telescope as picker
  },
  event = 'LspAttach',
  opts = {
    backend = 'vim',
    picker = 'telescope', -- switched to telescope
  },
  signs = {
    quickfix = { '', { link = 'DiagnosticWarning' } },
    others = { '', { link = 'DiagnosticWarning' } },
    refactor = { '', { link = 'DiagnosticInfo' } },
    ['refactor.move'] = { '󰪹', { link = 'DiagnosticInfo' } },
    ['refactor.extract'] = { '', { link = 'DiagnosticError' } },
    ['source.organizeImports'] = { '', { link = 'DiagnosticWarning' } },
    ['source.fixAll'] = { '󰃢', { link = 'DiagnosticError' } },
    ['source'] = { '', { link = 'DiagnosticError' } },
    ['rename'] = { '󰑕', { link = 'DiagnosticWarning' } },
    ['codeAction'] = { '', { link = 'DiagnosticWarning' } },
  },
  -- Key mapping
  keys = {
    {
      '<leader>ca',
      function()
        require('tiny-code-action').code_action {}
      end,
      desc = 'Trigger code actions',
    },
  },
}
