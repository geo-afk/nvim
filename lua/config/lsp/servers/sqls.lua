return {
  settings = {
    sqls = {
      lowercaseKeywords = false,
      connections = {
        {
          driver = 'postgresql',
          dataSourceName = 'host=127.0.0.1 port=5432 user=postgres password=pascal321 dbname=va-boss sslmode=disable',
        },
      },
      formatting = {
        enable = false,
        keywordCase = 'upper', -- 'upper' or 'lower'
        lineWidth = 120, -- max line width
        indentWidth = 2, -- spaces per indent
        expandComma = true, -- put comma at end of line
      },
      linting = {
        enable = true, -- enable SQL linting
        rules = { -- specify linting rules
          'no_select_star',
          'require_where_clause',
          'uppercase_keywords',
          'toleratePlaceholders',
        },
      },
      completion = {
        enable = true, -- enable autocompletion
        table = true, -- suggest table names
        column = true, -- suggest column names
        function_ = true, -- suggest SQL functions
      },

      telemetry = {
        enable = false,
      },
    },
  },
}
