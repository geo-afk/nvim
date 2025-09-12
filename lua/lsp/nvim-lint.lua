return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require 'lint'
    local eslint = lint.linters.eslint_d
    lint.linters_by_ft = {
      sql = { 'sqlfluff' }, -- SQL
      html = { 'htmlhint' }, -- SQL
      go = { 'staticcheck' },
      typescript = { 'biomejs' }, -- TypeScript
      javascript = { 'biomejs' }, -- JavaScript
    }

    eslint.args = {
      '--no-warn-ignored',
      '--format',
      'json',
      '--stdin',
      '--stdin-filename',
      function()
        return vim.fn.expand '%:p'
      end,
    }
    -- Create an autocommand group for linting
    local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })

    -- Trigger linting on leave insert mode or after saving buffer
    vim.api.nvim_create_autocmd({ 'BufEnter', 'InsertLeave', 'BufWritePost' }, {
      group = lint_augroup,
      callback = function()
        lint.try_lint()
      end,
    })

    -- Optional: Keymap to manually lint
    vim.keymap.set('n', '<leader>l', function()
      lint.try_lint()
    end, { desc = 'Trigger linting for current file' })
  end,
}
