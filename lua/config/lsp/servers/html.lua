return {
  cmd          = { 'vscode-html-language-server', '--stdio' },
  filetypes    = { 'html' },
  root_markers = { 'package.json', '.git' },
  settings = {
    html = {
      validate = {
        styles = false,
      },
      format = {
        templating = true,
        wrapLineLength = 120,
        wrapAttributes = 'auto',
      },
      hover = {
        documentation = true,
        references = true,
      },
    },
  },
  init_options = {
    provideFormatter = true,
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { 'html', 'css', 'javascript' },
  },
}
