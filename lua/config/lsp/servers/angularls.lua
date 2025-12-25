local angular_paths = require 'utils.angular_location'

return {
  settings = {
    angularls = {
      experimental = {
        templateDiagnostics = true, -- Enable diagnostics for Angular templates
        templateCodeLens = true, -- Enable code lenses for template-related actions
      },
      provideFormatter = true, -- Enable formatting support for Angular files
      strictTemplates = true, -- Enforce strict template type checking
      trace = {
        server = 'messages', -- Options: "off", "messages", "verbose"
      },
    },
  },
  cmd = angular_paths.cmd,
  root_markers = { 'angular.json', 'nx.json' },
  filetypes = { 'html' },
}
