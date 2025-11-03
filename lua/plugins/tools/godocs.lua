return {
  'fredrikaverpil/godoc.nvim',
  version = '*',
  cmd = { 'GoDoc' }, -- optional
  opts = {
    picker = {
      type = 'snacks', -- native (vim.ui.select) | telescope | snacks | mini | fzf_lua
    },
  }, -- see further down below for configuration
}
