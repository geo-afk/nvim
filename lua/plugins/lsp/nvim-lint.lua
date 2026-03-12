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
      go = { 'staticcheck' },
      -- ["*"]    = { 'typos' },          -- global typo/spell checking (uncomment if desired)
      -- ["_"]    = { 'some_fallback' },  -- fallback for unknown filetypes
    }

    ------------------------------------------------------------------------
    -- Custom linter argument overrides
    ------------------------------------------------------------------------
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

    -- (eslint_d block removed as unused; re-add if you enable it in linters_by_ft)

    ------------------------------------------------------------------------
    -- Debounce helper
    ------------------------------------------------------------------------
    local function debounce(ms, fn)
      local timer = vim.uv.new_timer()
      if not timer then
        return function(...)
          fn(...)
        end -- fallback: no debounce
      end

      return function(...)
        local args = { ... }
        timer:stop()
        timer:start(
          ms,
          0,
          vim.schedule_wrap(function()
            fn(unpack(args))
          end)
        )
      end
    end

    ------------------------------------------------------------------------
    -- Lint runner with safety
    ------------------------------------------------------------------------
    local function run_lint()
      if not vim.bo.modifiable or vim.bo.buftype ~= '' then
        return
      end

      local names = lint._resolve_linter_by_ft(vim.bo.filetype)
      names = vim.list_extend({}, names or {})

      -- Fallback + global
      if #names == 0 then
        vim.list_extend(names, lint.linters_by_ft['_'] or {})
      end
      vim.list_extend(names, lint.linters_by_ft['*'] or {})

      -- Filter valid linters only
      names = vim.tbl_filter(function(name)
        if not lint.linters[name] then
          vim.notify('nvim-lint: linter not found: ' .. name, vim.log.levels.WARN)
          return false
        end
        return true
      end, names)

      if #names > 0 then
        local ok = pcall(lint.try_lint, names)
        if not ok then
          vim.notify('nvim-lint: try_lint failed', vim.log.levels.ERROR)
        end
      end
    end

    ------------------------------------------------------------------------
    -- Autocommands
    ------------------------------------------------------------------------
    local augroup = vim.api.nvim_create_augroup('NvimLint', { clear = true })

    vim.api.nvim_create_autocmd(
      { 'BufEnter', 'BufWritePost', 'InsertLeave' },
      -- Optional: add 'TextChanged' for live lint-as-you-type (with debounce!)
      -- { 'BufEnter', 'TextChanged', 'TextChangedI', 'BufWritePost', 'InsertLeave' },
      {
        group = augroup,
        callback = debounce(200, run_lint), -- 200 ms is a good balance
      }
    )
  end,
}
