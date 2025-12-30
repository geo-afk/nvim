return {
  'nvim-treesitter/nvim-treesitter',
  event = { 'BufReadPre', 'BufNewFile' },
  branch = 'master',
  build = ':TSUpdate',

  -- Treesitter configuration
  opts = {
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

    sync_install = false, -- don't block on install
    auto_install = true, -- install missing parsers on demand

    highlight = {
      enable = true,
      -- If you depend on regex highlighting for some languages
      -- additional_vim_regex_highlighting = { 'ruby' },
      additional_vim_regex_highlighting = false,
    },

    indent = {
      enable = true,
      disable = { 'ruby' },
    },
  },

  config = function(_, opts)
    -- Apply the treesitter setup
    require('nvim-treesitter.configs').setup(opts)

    -- Optional: Better Angular templates detection
    -- Trigger angular parser for *.component.html files
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
      pattern = { '*.component.html', '*.html' },
      callback = function(args)
        local buf = args.buf
        local path = vim.api.nvim_buf_get_name(buf)

        -- Only care about Angular component templates
        if path:match '/src/app/' then
          local angular_json = vim.fn.findfile('angular.json', vim.fn.getcwd() .. ';')
          if angular_json ~= '' then
            -- Use treesitter start for angular if available
            local ok = pcall(vim.treesitter.get_parser, buf, 'angular')
            if ok then
              vim.notify('Angular', 'debug')
              vim.treesitter.start(buf, 'angular')
            else
              -- Fallback to default html highlighting
              vim.treesitter.start(buf, 'html')
            end
          end
        end
      end,
    })

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'go',
      callback = function()
        vim.treesitter.language.add 'sql'
      end,
    })
  end,
}
