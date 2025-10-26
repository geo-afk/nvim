return {
  'folke/trouble.nvim',
  cmd = { 'Trouble' },
  opts = function()
    local has_webdevicons, webdevicons = pcall(require, 'nvim-web-devicons')
    local kinds = {}

    if has_webdevicons then
      -- Map LSP kinds to WebDevIcons (or fallback to simple icons)
      local kind_mapping = {
        Array = 'array',
        Boolean = 'boolean',
        Class = 'class',
        Constant = 'constant',
        Constructor = 'constructor',
        Enum = 'enum',
        EnumMember = 'enummember',
        Event = 'event',
        Field = 'field',
        File = 'file',
        Function = 'function',
        Interface = 'interface',
        Key = 'key',
        Method = 'method',
        Module = 'module',
        Namespace = 'namespace',
        Null = 'null',
        Number = 'number',
        Object = 'object',
        Operator = 'operator',
        Package = 'package',
        Property = 'property',
        String = 'string',
        Struct = 'struct',
        TypeParameter = 'typeparameter',
        Variable = 'variable',
      }

      for trouble_kind, icon_name in pairs(kind_mapping) do
        local icon = webdevicons.get_icon(icon_name)
        kinds[trouble_kind] = icon or '' -- fallback icon if none found
      end
    end

    return {
      modes = {
        lsp = { win = { position = 'right' } },
      },
      icons = {
        kinds = kinds,
      },
    }
  end,
  config = function(_, opts)
    require('trouble').setup(opts)
  end,
  keys = {
    { '<leader>xx', '<Cmd>Trouble diagnostics toggle<CR>', desc = 'Diagnostics (Trouble)' },
    { '<leader>xX', '<Cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Buffer Diagnostics (Trouble)' },
    { '<leader>xL', '<Cmd>Trouble loclist toggle<CR>', desc = 'Location List (Trouble)' },
    { '<leader>xQ', '<Cmd>Trouble qflist toggle<CR>', desc = 'Quickfix List (Trouble)' },
    {
      '[q',
      function()
        if require('trouble').is_open() then
          require('trouble').prev { skip_groups = true, jump = true }
        else
          local ok, err = pcall(vim.cmd.cprev)
          if not ok then
            vim.notify(err, vim.log.levels.ERROR)
          end
        end
      end,
      desc = 'Previous Trouble/Quickfix Item',
    },
    {
      ']q',
      function()
        if require('trouble').is_open() then
          require('trouble').next { skip_groups = true, jump = true }
        else
          local ok, err = pcall(vim.cmd.cnext)
          if not ok then
            vim.notify(err, vim.log.levels.ERROR)
          end
        end
      end,
      desc = 'Next Trouble/Quickfix Item',
    },
  },
}
