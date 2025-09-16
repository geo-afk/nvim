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
      telemetry = {
        enable = false,
      },
    },
  },
}
