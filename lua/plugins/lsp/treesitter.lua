return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'master', -- use the frozen backward-compatible branch
  event = { 'BufReadPre', 'BufNewFile' },
  build = ':TSUpdate',

  opts = {}, -- we will use config() manually

  config = function()
    -- Safe require
    local ok, configs = pcall(require, 'nvim-treesitter.configs')
    if not ok then
      vim.notify('[Treesitter] nvim-treesitter.configs missing!', vim.log.levels.WARN)
      return
    end

    -- =========================================================================
    -- Treesitter Setup
    -- =========================================================================
    configs.setup {
      -- Languages to ensure are installed
      ensure_installed = {
        'bash',
        'c',
        'go',
        'html',
        'javascript',
        'lua',
        'markdown',
        'markdown_inline',
        'scss',
        'sql',
        'typescript',
        'vim',
        'vimdoc',
      },

      -- Install missing parsers automatically
      sync_install = false,
      auto_install = true,

      -- Highlighting
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },

      -- Indentation
      indent = {
        enable = true,
        disable = { 'ruby' },
      },

      -- Incremental Selection
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<CR>',
          node_incremental = '<CR>',
          scope_incremental = false,
          node_decremental = '<BS>',
        },
      },
    }

    -- =========================================================================
    -- Optional Fold Settings (Treesitter-based folding)
    -- =========================================================================
    vim.api.nvim_create_autocmd('FileType', {
      pattern = '*',
      callback = function()
        -- vim.wo.foldmethod = 'expr'
        -- vim.wo.foldexpr = 'nvim_treesitter#foldexpr()'
      end,
      desc = 'Enable treesitter-based folding',
    })

    -- =========================================================================
    -- Angular Template Treesitter Logic
    -- =========================================================================
    local utils_ok, utils = pcall(require, 'utils')
    utils = utils_ok and utils or {}

    local function is_angular_project()
      if type(utils.is_angular_project) == 'function' then
        return utils.is_angular_project()
      end
      return false
    end

    local function should_use_angular_parser(path)
      if not path or type(path) ~= 'string' then
        return false
      end
      if not path:match '/src/app/' then
        return false
      end
      return is_angular_project()
    end

    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
      pattern = { '*.component.html', '*.html' },
      callback = function(args)
        local buf = args.buf
        local path = vim.api.nvim_buf_get_name(buf)
        if should_use_angular_parser(path) then
          local okay, _ = pcall(vim.treesitter.get_parser, buf, 'angular')
          if okay then
            pcall(vim.treesitter.start, buf, 'angular')
          else
            pcall(vim.treesitter.start, buf, 'html')
          end
        end
      end,
      desc = 'Apply Angular Treesitter parser or fallback',
    })
  end,
}
