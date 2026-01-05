return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  branch = 'main', -- Recommended; master is frozen
  lazy = true,
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  event = 'VeryLazy', -- Optional but recommended
  opts = {
    move = {
      enable = true,
      set_jumps = true,
      keys = {
        goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer', [']a'] = '@parameter.inner' },
        goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer', [']A'] = '@parameter.inner' },
        goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer', ['[a'] = '@parameter.inner' },
        goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer', ['[A'] = '@parameter.inner' },
      },
    },
  },
  config = function(_, opts)
    -- No separate setup needed; the plugin attaches via nvim-treesitter.configs

    local function attach(buf)
      local ft = vim.bo[buf].filetype

      -- Simplified guard: only attach if move is enabled
      if not vim.tbl_get(opts, 'move', 'enable') then
        return
      end

      local moves = vim.tbl_get(opts, 'move', 'keys') or {}
      for method, keymaps in pairs(moves) do
        for key, query in pairs(keymaps) do
          local queries = type(query) == 'table' and query or { query }
          local parts = {}
          for _, q in ipairs(queries) do
            local part = q:gsub('@', ''):gsub('%..*', '')
            part = part:sub(1, 1):upper() .. part:sub(2) -- Proper capitalization
            table.insert(parts, part)
          end
          local desc = table.concat(parts, ' or ')
          desc = (key:sub(1, 1) == '[' and 'Prev ' or 'Next ') .. desc
          desc = desc .. (key:sub(2, 2):upper() == key:sub(2, 2) and ' End' or ' Start')

          if not (vim.wo.diff and key:find '[cC]') then
            vim.keymap.set({ 'n', 'x', 'o' }, key, function()
              require('nvim-treesitter-textobjects.move')[method](queries, 'textobjects')
            end, {
              buffer = buf,
              desc = desc,
              silent = true,
            })
          end
        end
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter_textobjects_move', { clear = true }),
      callback = function(ev)
        attach(ev.buf)
      end,
    })

    -- Apply to existing buffers
    vim.tbl_map(attach, vim.api.nvim_list_bufs())
  end,
}
