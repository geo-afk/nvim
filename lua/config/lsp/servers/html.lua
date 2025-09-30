-- lua/plugins/lsp/html.lua (or wherever you configure LSPs)

return {
  settings = {
    html = {
      validate = {
        styles = false, -- Disable CSS validation in HTML
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
  filetypes = { 'html', 'htmlangular' }, -- explicitly set filetypes
}
