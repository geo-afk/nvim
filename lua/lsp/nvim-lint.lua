return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require 'lint'
    local eslint = lint.linters.eslint_d
    local sqruff = lint.linters.sqruff -- Reference to sqruff linter

    lint.linters_by_ft = {
      sql = { 'sqruff' }, -- SQL
      html = { 'htmlhint' }, -- HTML
      go = { 'staticcheck', 'typos' },
      typescript = { 'biomejs' }, -- TypeScript
      javascript = { 'biomejs' }, -- JavaScript
      lua = { 'typos' }, -- JavaScript
    }

    -- Configure eslint_d args (unchanged)
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

    -- Configure sqruff args to point to a config file
    sqruff.args = {
      '--format',
      'json', -- Output format compatible with nvim-lint
      '--config',
      vim.fn.stdpath 'config' .. '\\.sqruff',
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
