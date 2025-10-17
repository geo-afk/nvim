return {
  'DrKJeff16/project.nvim',
  lazy = true,
  version = false, -- Get the latest release
  cmd = { -- Lazy-load by commands
    'Project',
    'ProjectAdd',
    'ProjectConfig',
    'ProjectDelete',
    'ProjectHistory',
    'ProjectRecents',
    'ProjectRoot',
    'ProjectSession',
  },
  ---@type Project.Config.Options
  opts = {},
}
