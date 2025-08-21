-- lua/plugins/actions-preview.lua
return {
  {
    'aznhe21/actions-preview.nvim',
    event = 'LspAttach',
    dependencies = {
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('actions-preview').setup {
        -- Backend selection - telescope is the main one we want
        backend = { 'telescope' },

        -- Only supported telescope options
        telescope = {
          sorting_strategy = 'ascending',
          layout_strategy = 'vertical',
          layout_config = {
            width = 0.8,
            height = 0.9,
            prompt_position = 'top',
            preview_cutoff = 20,
          },
        },

        -- Diff context lines (this is supported)
        diff = {
          ctxlen = 3,
        },
      }

      -- Main keybinding for code actions
      vim.keymap.set({ 'n', 'v' }, '<leader>ca', require('actions-preview').code_actions, {
        desc = 'LSP Code Actions Preview',
        silent = true,
      })

      -- Quick fix shortcut
      vim.keymap.set('n', '<leader>cq', function()
        vim.lsp.buf.code_action {
          filter = function(action)
            return action.kind == 'quickfix'
          end,
          apply = true,
        }
      end, {
        desc = 'Quick Fix (Auto-apply)',
        silent = true,
      })

      -- Fix for hover behavior in floating windows
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('ActionsPreviewHoverFix', { clear = true }),
        callback = function(ev)
          vim.keymap.set('n', 'Q', function()
            local win_config = vim.api.nvim_win_get_config(0)
            if win_config.relative ~= '' then
              return -- Don't trigger in floating windows
            end
            vim.lsp.buf.hover()
          end, {
            buffer = ev.buf,
            silent = true,
            desc = 'LSP Hover',
          })
        end,
      })
    end,
  },
}
