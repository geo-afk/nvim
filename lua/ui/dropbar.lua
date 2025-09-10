return {
  'Bekaboo/dropbar.nvim',
  -- optional, but required for fuzzy finder support
  dependencies = {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
  },
  config = function()
    local api = require 'dropbar.api'

    -- From the docs
    vim.keymap.set('n', '<Leader>;', api.pick, { desc = 'Dropbar: pick symbols in winbar' })
    vim.keymap.set('n', '[;', api.goto_context_start, { desc = 'Dropbar: go to start of current context' })
    vim.keymap.set('n', '];', api.select_next_context, { desc = 'Dropbar: select next context' })

    -- Extra: previous/next context (guard prev in case your version doesn't have it)
    if api.select_prev_context then
      vim.keymap.set('n', '[c', api.select_prev_context, { desc = 'Dropbar: select previous context' })
    end
    vim.keymap.set('n', ']c', api.select_next_context, { desc = 'Dropbar: select next context' })
  end,
}
