return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPost', 'BufNewFile', 'BufWritePost', 'InsertLeave' },
  config = function()
    local lint = require 'lint'

    ------------------------------------------------------------------------
    -- Linters by filetype
    ------------------------------------------------------------------------
    lint.linters_by_ft = {
      sql = { 'sqruff' },
      html = { 'htmlhint' },
      typescript = { 'biome' },
      javascript = { 'biome' },
      lua = { 'typos' },
      python = { 'ruff' },
      -- go = { "staticcheck" },
      -- ["*"] = { "typos" },
      -- ["_"] = { "fallback_linter" },
    }

    ------------------------------------------------------------------------
    -- Custom linter argument overrides
    ------------------------------------------------------------------------
    if lint.linters.eslint_d then
      lint.linters.eslint_d.args = {
        '--no-warn-ignored',
        '--format',
        'json',
        '--stdin',
        '--stdin-filename',
        vim.fn.expand '%:p',
      }
    end

    if lint.linters.sqruff then
      lint.linters.sqruff.args = {
        '--format',
        'json',
        '--config',
        vim.fs.joinpath(vim.fn.stdpath 'config', '.sqruff.toml'),
        '--stdin',
        '--stdin-filename',
        vim.fn.expand '%:p',
      }
    end

    ------------------------------------------------------------------------
    -- Debounce helper (prevents excessive lint runs)
    ------------------------------------------------------------------------
    local function debounce(ms, fn)
      local timer = vim.uv.new_timer()

      -- Timer allocation failed → graceful fallback
      if not timer then
        return function(...)
          local args = { ... }
          vim.schedule(function()
            fn(unpack(args))
          end)
        end
      end

      return function(...)
        local args = { ... }

        timer:stop()
        timer:start(ms, 0, function()
          vim.schedule(function()
            fn(unpack(args))
          end)
        end)
      end
    end

    ------------------------------------------------------------------------
    -- Lint runner with safety checks
    ------------------------------------------------------------------------
    local function run_lint()
      -- Avoid linting non-file buffers
      if not vim.bo.modifiable or vim.bo.buftype ~= '' then
        return
      end

      -- Resolve linters using nvim-lint's internal logic
      local names = lint._resolve_linter_by_ft(vim.bo.filetype)
      names = vim.list_extend({}, names)

      -- Fallback linters
      if #names == 0 then
        vim.list_extend(names, lint.linters_by_ft['_'] or {})
      end

      -- Global linters
      vim.list_extend(names, lint.linters_by_ft['*'] or {})

      -- Filter invalid linters
      names = vim.tbl_filter(function(name)
        if not lint.linters[name] then
          vim.notify('nvim-lint: linter not found: ' .. name, vim.log.levels.WARN)
          return false
        end
        return true
      end, names)

      if #names > 0 then
        lint.try_lint(names)
      end
    end

    ------------------------------------------------------------------------
    -- Autocommands
    ------------------------------------------------------------------------
    local augroup = vim.api.nvim_create_augroup('NvimLint', { clear = true })

    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
      group = augroup,
      callback = debounce(100, run_lint),
    })
  end,
}
