return {
  'nvim-treesitter/nvim-treesitter',
  event = { 'BufReadPre', 'BufNewFile' },
  branch = 'master',
  build = ':TSUpdate',

  -- ============================================================================
  -- Treesitter Base Configuration
  -- ============================================================================
  opts = {
    -- Languages to ensure are installed
    ensure_installed = {
      'c',
      'go',
      'sql',
      'vim',
      'lua',
      'bash',
      'html',
      'diff',
      'scss',
      'vimdoc',
      'angular',
      'markdown',
      'javascript',
      'typescript',
      'markdown_inline',
    },

    sync_install = false, -- Install parsers asynchronously
    auto_install = true, -- Install missing parsers automatically

    -- Syntax highlighting
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },

    -- Smart indentation
    indent = {
      enable = true,
      disable = { 'ruby' }, -- Ruby has better indent support elsewhere
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<CR>', -- set to `false` to disable one of the mappings
        node_incremental = '<CR>',
        scope_incremental = false,
        node_decremental = '<BS>',
      },
    },
  },

  -- ============================================================================
  -- Configuration Function
  -- ============================================================================
  config = function(_, opts)
    local utils = require 'utils' -- Adjust path if needed

    -- Apply base treesitter configuration
    require('nvim-treesitter.configs').setup(opts)

    -- ------------------------------------------------------------------------
    -- Angular Template Detection
    -- ------------------------------------------------------------------------

    --- Determine if a file should use Angular treesitter parser
    --- @param buf number Buffer handle
    --- @param path string File path
    --- @return boolean True if file should use Angular parser
    local function should_use_angular_parser(buf, path)
      -- Only check files in Angular src directories
      if not path:match '/src/app/' then
        return false
      end

      -- Verify we're in an Angular project
      return utils.is_angular_project()
    end

    --- Set up treesitter parser for Angular template files
    --- @param buf number Buffer handle
    --- @param path string File path
    local function setup_angular_treesitter(buf, path)
      if not should_use_angular_parser(buf, path) then
        return
      end

      -- Try to use Angular parser, fallback to HTML
      local ok = pcall(vim.treesitter.get_parser, buf, 'angular')

      if ok then
        vim.treesitter.start(buf, 'angular')
      else
        -- Fallback to standard HTML highlighting
        vim.treesitter.start(buf, 'html')
      end
    end

    -- Set up autocmd for Angular template files
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
      pattern = { '*.component.html', '*.html' },
      callback = function(args)
        local buf = args.buf
        local path = vim.api.nvim_buf_get_name(buf)
        setup_angular_treesitter(buf, path)
      end,
      desc = 'Set up Angular treesitter parser for component templates',
    })

    -- ------------------------------------------------------------------------
    -- Language-Specific Configuration
    -- ------------------------------------------------------------------------

    -- Add SQL language support for Go files (for embedded SQL)
    -- vim.api.nvim_create_autocmd('FileType', {
    --   pattern = 'go',
    --   callback = function()
    --     vim.treesitter.language.add 'sql'
    --   end,
    --   desc = 'Add SQL language support for Go files',
    -- })
  end,
}
