local capabilities = require('blink.cmp').get_lsp_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.colorProvider = { dynamicRegistration = false }
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

return {
  settings = {
    tailwindCSS = {
      emmetCompletions = true,
      validate = true,
      lint = {
        cssConflict = 'warning',
        invalidApply = 'error',
        invalidScreen = 'error',
        invalidVariant = 'error',
        invalidConfigPath = 'error',
        invalidTailwindDirective = 'error',
        recommendedVariantOrder = 'warning',
      },
      -- Tailwind class attributes configuration
      classAttributes = { 'class', 'className', 'classList', 'ngClass', ':class' },

      -- Experimental regex patterns to detect Tailwind classes in various syntaxes
      experimental = {
        classRegex = {
          -- tw`...` or tw("...")
          'tw`([^`]*)`',
          'tw\\(([^)]*)\\)',

          -- @apply directive inside SCSS / CSS
          '@apply\\s+([^;]*)',

          -- class and className attributes (HTML, JSX, Vue, Blade with :class)
          'class="([^"]*)"',
          'className="([^"]*)"',
          ':class="([^"]*)"',

          -- Laravel @class directive e.g. @class([ ... ])
          '@class\\(([^)]*)\\)',

          -- 'tw="([^"]*)',
          -- 'tw={"([^"}]*)',
          -- 'tw\\.\\w+`([^`]*)',
          -- 'tw\\(.*?\\)`([^`]*)',
          -- { 'clsx\\(([^)]*)\\)', "(?:'|\"|`)([^']*)(?:'|\"|`)" },
          -- { 'classnames\\(([^)]*)\\)', "'([^']*)'" },
          -- { 'cva\\(([^)]*)\\)', '["\'`]([^"\'`]*).*?["\'`]' },
          -- { 'cn\\(([^)]*)\\)', "(?:'|\"|`)([^']*)(?:'|\"|`)" },
        },
      },
    },
  },
}
