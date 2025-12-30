local M = {}

M.git_icons = {
  added = ' ',
  modified = ' ',
  removed = ' ',
}

M.diagnostic_icons = {
  Error = ' ',
  Warn = ' ',
  Info = ' ',
  Hint = '󰌵 ',
}

M.devicons_override = {
  default_icon = {
    icon = '󰈚',
    name = 'Default',
    color = '#E06C75',
  },
  toml = {
    icon = '',
    name = 'toml',
    color = '#61AFEF',
  },
  tsx = {
    icon = '',
    name = 'Tsx',
    color = '#20c2e3',
  },
  gleam = {
    icon = '',
    name = 'Gleam',
    color = '#FFAFF3',
  },
  py = {
    icon = '',
    color = '#519ABA',
    cterm_color = '214',
    name = 'Py',
  },
}

return M
